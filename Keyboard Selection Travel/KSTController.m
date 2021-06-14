//
//  KSTController.m
//  Keyboard Selection Travel
//
//  Copyright 2021 Florian Pircher
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "KSTController.h"
#import "KSTCandidate.h"

static NSString * const kGlyphsHandleSizeKey = @"GSHandleSize";
static NSString * const kGlyphsDrawOptionScaleKey = @"Scale";

typedef NS_ENUM(NSUInteger, KSTTravel) {
    KSTTravelUp,
    KSTTravelDown,
    KSTTravelLeft,
    KSTTravelRight,
};

@interface KSTController ()
@property (atomic, assign) BOOL useAlternativeShortcuts;
@property (nonatomic, retain) NSSet *ignoreToolClassNameSet;
@property (atomic, assign) BOOL showHints;
@property (atomic, assign) int hintSize;
@property (nonatomic, retain) NSColor *hintColor;
@property (nonatomic, assign) BOOL travelHintsActive;
@property (nonatomic, retain) NSMutableSet *skippedCandidates;
@end

@implementation KSTController

+ (void)initialize
{
    if (self == [KSTController class]) {
        [NSUserDefaults.standardUserDefaults registerDefaults:@{
            kUseAlternativeShortcutsKey: @NO,
            kIgnoreToolsKey: @[@"GlyphsToolText"],
            kShowHintsKey: @YES,
            kHintSizeKey: @-1,
            kHintColorKey: @-1,
        }];
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self refreshUserDefaultsValueForKey:kUseAlternativeShortcutsKey];
        [self refreshUserDefaultsValueForKey:kIgnoreToolsKey];
        [self refreshUserDefaultsValueForKey:kShowHintsKey];
        [self refreshUserDefaultsValueForKey:kHintSizeKey];
        [self refreshUserDefaultsValueForKey:kHintColorKey];
        _travelHintsActive = NO;
        _skippedCandidates = [NSMutableSet set];
    }
    return self;
}

- (void)refreshUserDefaultsValueForKey:(NSString *)key {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    
    if ([key isEqualToString:kUseAlternativeShortcutsKey]) {
        self.useAlternativeShortcuts = [defaults boolForKey:kUseAlternativeShortcutsKey];
    }
    else if ([key isEqualToString:kIgnoreToolsKey]) {
        NSArray<NSString *> *ignoreToolClassNames = [defaults arrayForKey:kIgnoreToolsKey];
        NSMutableSet<NSString *> *ignoreToolClassNameSet = [NSMutableSet new];
        
        if (ignoreToolClassNames != nil) {
            for (NSString *className in ignoreToolClassNames) {
                if ([className isKindOfClass:[NSString class]]) {
                    [ignoreToolClassNameSet addObject:className];
                }
            }
        }
        
        self.ignoreToolClassNameSet = ignoreToolClassNameSet;
    }
    else if ([key isEqualToString:kShowHintsKey]) {
        self.showHints = [defaults boolForKey:kShowHintsKey];
    }
    else if ([key isEqualToString:kHintSizeKey]) {
        int hintSize = (int)[defaults integerForKey:kHintSizeKey];
        
        if (hintSize == -1) {
            hintSize = (int)[defaults integerForKey:kGlyphsHandleSizeKey];
        }
        
        self.hintSize = hintSize;
    }
    else if ([key isEqualToString:kHintColorKey]) {
        int hintColorId = (int)[defaults integerForKey:kHintColorKey];
        
        switch (hintColorId) {
        case 0: self.hintColor = [NSColor systemRedColor]; break;
        case 1: self.hintColor = [NSColor systemOrangeColor]; break;
        case 2: self.hintColor = [NSColor systemBrownColor]; break;
        case 3: self.hintColor = [NSColor systemYellowColor]; break;
        case 4: self.hintColor = [NSColor systemGreenColor]; break;
        case 7: self.hintColor = [NSColor systemBlueColor]; break;
        case 8: self.hintColor = [NSColor systemPurpleColor]; break;
        case 9: self.hintColor = [NSColor systemPinkColor]; break;
        default: self.hintColor = [NSColor systemGrayColor]; break;
        }
    }
}

- (nullable NSViewController<GSGlyphEditViewControllerProtocol> *)editViewController {
    return ((GSApplication *)NSApp).currentFontDocument.windowController.activeEditViewController;
}

- (BOOL)travelActive {
    GSApplication *app = NSApp;
    GSDocument *document = app.currentFontDocument;
    
    if (document == nil) {
        return NO;
    }
    
    NSWindowController<GSWindowControllerProtocol> *windowController = document.windowController;
    
    if (windowController == nil || [windowController.window isNotEqualTo:app.keyWindow]) {
        // Edit view must be in key window for plugin to apply
        return NO;
    }
    
    if ([self.ignoreToolClassNameSet containsObject:windowController.toolDrawDelegate.className]) {
        // Control-Up/Down/Left/Right (with out without Shift) is already used by Text tool
        return NO;
    }
    
    GSFont *font = document.font;
    
    if (font == nil) {
        return NO;
    }
    
    return YES;
}

- (NSUInteger)interfaceVersion {
    return 1;
}

- (void)loadPlugin {
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown|NSEventMaskFlagsChanged handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        NSUInteger flags = event.modifierFlags & kEventModifierKeyFlagsMask;
        BOOL isFlagsChange = event.type == NSEventTypeFlagsChanged;
        BOOL isTravel;
        
        if (self.useAlternativeShortcuts) {
            // alternative shortcuts are Control-Shift with the Up/Down/Left/Right arow keys
            isTravel = flags == (NSEventModifierFlagControl|NSEventModifierFlagShift)
                || (isFlagsChange && flags == (NSEventModifierFlagControl|NSEventModifierFlagShift|NSEventModifierFlagCommand));
        } else {
            // standard shortcuts are Control with the Up/Down/Left/Right arow keys
            isTravel = flags == NSEventModifierFlagControl
                || (isFlagsChange && flags == (NSEventModifierFlagControl|NSEventModifierFlagCommand));
        }
        
        if (isFlagsChange) {
            self.travelHintsActive = isTravel;
            
            if (isTravel) {
                if (flags & NSEventModifierFlagCommand) {
                    [self cycleCandidates];
                    [self.editViewController redraw];
                }
            }
            else {
                [self resetSkippedCandidates];
            }
        }
        else if (event.type == NSEventTypeKeyDown && isTravel && self.travelActive) {
            unichar character = [event.charactersIgnoringModifiers characterAtIndex:0];
            BOOL didTravel = [self travelForCharacter:character];
            
            if (didTravel) {
                return nil;
            }
        }
        
        return event;
    }];
    
    [GSCallbackHandler addCallback:self forOperation:GSDrawForegroundCallbackName];
}

- (BOOL)travelForCharacter:(unichar)charachter {
    switch (charachter) {
    case NSUpArrowFunctionKey:
        return [self travel:KSTTravelUp];
    case NSDownArrowFunctionKey:
        return [self travel:KSTTravelDown];
    case NSLeftArrowFunctionKey:
        return [self travel:KSTTravelLeft];
    case NSRightArrowFunctionKey:
        return [self travel:KSTTravelRight];
    default:
        return NO;
    }
}

- (BOOL)travel:(KSTTravel)travel {
    CGFloat upm = ((GSApplication *)NSApp).currentFontDocument.font.unitsPerEm;
    GSLayer *layer = self.editViewController.activeLayer;
    NSMutableOrderedSet<GSSelectableElement *> *selection = layer.selection;
    
    if (selection == nil) {
        return NO;
    }
    
    NSArray<KSTCandidate *> *candidates = [self targetsForTravel:travel fromSelection:selection onLayer:layer atScale:upm];
    
    // the elements to select
    NSMutableOrderedSet<GSSelectableElement *> *newSelection = [NSMutableOrderedSet new];
    
    for (int i = 0; i < candidates.count; i++) {
        KSTCandidate *c = candidates[i];
        GSSelectableElement *element;
        
        if (c.element == nil) {
            // no target was found, keep current selection
            element = selection[i];
        } else {
            // select the new target element
            element = c.element;
        }
        
        [newSelection addObject:element];
    }
    
    [self.editViewController.activeLayer setSelection:newSelection];
    
    return YES;
}

- (NSArray<KSTCandidate *> *)targetsForTravel:(KSTTravel)travel fromSelection:(NSOrderedSet<GSSelectableElement *> *)selection onLayer:(GSLayer *)layer atScale:(CGFloat)scale {
    // candidates are points which might be the travel target
    NSMutableArray<KSTCandidate *> *candidates = [NSMutableArray arrayWithCapacity:selection.count];
    
    // populate `candidates` with all points of the current selection
    // in case no target is found, the current selection kept
    // set `element` to `nil` to indicate “no change”
    // set distance to max so other points have a chance to become target
    // the current selection points are placed first in `candidates` so they are picked in case all other candidates also have max distance
    for (int i = 0; i < selection.count; i++) {
        KSTCandidate *candidate = [KSTCandidate new];
        candidate.distance = CGFLOAT_MAX;
        candidate.element = nil;
        [candidates addObject:candidate];
    }
    
    // evaluate all points
    for (GSPath *path in layer.paths) {
        for (GSNode *node in path.nodes) {
            for (int i = 0; i < selection.count; i++) {
                [self evaluateCandidate:candidates[i] fromOrigin:(GSShape *)selection[i] toTarget:node atScale:scale withTravel:travel];
            }
        }
    }
    
    // evaluate all anchors
    for (NSString *anchorName in layer.anchors) {
        GSAnchor *anchor = [layer.anchors objectForKey:anchorName];
        
        for (int i = 0; i < selection.count; i++) {
            [self evaluateCandidate:candidates[i] fromOrigin:(GSShape *)selection[i] toTarget:anchor atScale:scale withTravel:travel];
        }
    }
    
    return candidates;
}

- (void)evaluateCandidate:(KSTCandidate *)candidate
               fromOrigin:(GSShape *)origin
                 toTarget:(GSElement *)target
                  atScale:(CGFloat)scale
               withTravel:(KSTTravel)travel {
    if ([origin isEqualTo:target]) {
        return;
    }
    if ([self.skippedCandidates containsObject:target]) {
        return;
    }
    
    CGFloat distance = [self distanceFrom:origin to:target atScale:scale withTravel:travel];
    
    if (distance < candidate.distance) {
        candidate.distance = distance;
        candidate.element = target;
    }
}

- (CGFloat)distanceFrom:(GSShape *)s1 to:(GSShape *)s2 atScale:(CGFloat)scale withTravel:(KSTTravel)travel {
    CGFloat x1 = s1.position.x / scale + 1;
    CGFloat y1 = s1.position.y / scale + 1;
    CGFloat x2 = s2.position.x / scale + 1;
    CGFloat y2 = s2.position.y / scale + 1;
    
    if (travel == KSTTravelUp && y1 >= y2) {
        return CGFLOAT_MAX;
    }
    if (travel == KSTTravelDown && y1 <= y2) {
        return CGFLOAT_MAX;
    }
    if (travel == KSTTravelLeft && x1 <= x2) {
        return CGFLOAT_MAX;
    }
    if (travel == KSTTravelRight && x1 >= x2) {
        return CGFLOAT_MAX;
    }
    
    CGFloat dx = fabs(x1 - x2);
    CGFloat dy = fabs(y1 - y2);
    
    BOOL isVertical = travel == KSTTravelUp || travel == KSTTravelDown;
    // primary delta
    CGFloat dp = isVertical ? dy : dx;
    // secondary delta
    CGFloat ds = isVertical ? dx : dy;
    
    CGFloat distance = -atan2(dp, ds / 4) + dp + ds;
    
    return distance;
}

- (void)setTravelHintsActive:(BOOL)travelHintsActive {
    if (_travelHintsActive == travelHintsActive) {
        return;
    }
    
    _travelHintsActive = travelHintsActive;
    
    [self.editViewController redraw];
}

- (void)drawForegroundForLayer:(GSLayer *)layer options:(NSDictionary *)options {
    GSLayer *activeLayer = self.editViewController.activeLayer;
    
    if ([layer isNotEqualTo:activeLayer]) {
        return;
    }
    
    if (self.showHints && self.travelHintsActive && self.travelActive) {
        CGFloat scale = [options[kGlyphsDrawOptionScaleKey] doubleValue];
        CGFloat upm = ((GSApplication *)NSApp).currentFontDocument.font.unitsPerEm;
        NSMutableOrderedSet<GSSelectableElement *> *selection = layer.selection;
        
        NSArray<KSTCandidate *> *upTargets = [self targetsForTravel:KSTTravelUp fromSelection:selection onLayer:layer atScale:upm];
        NSArray<KSTCandidate *> *downTargets = [self targetsForTravel:KSTTravelDown fromSelection:selection onLayer:layer atScale:upm];
        NSArray<KSTCandidate *> *leftTargets = [self targetsForTravel:KSTTravelLeft fromSelection:selection onLayer:layer atScale:upm];
        NSArray<KSTCandidate *> *rightTargets = [self targetsForTravel:KSTTravelRight fromSelection:selection onLayer:layer atScale:upm];
        
        for (int i = 0; i < selection.count; i++) {
            KSTCandidate *upCandidate = upTargets[i];
            KSTCandidate *downCandidate = downTargets[i];
            KSTCandidate *leftCandidate = leftTargets[i];
            KSTCandidate *rightCandidate = rightTargets[i];
            
            if (upCandidate.element != nil) {
                [self drawHintForTravel:KSTTravelUp atPoint:upCandidate.element.position atScale:scale];
            }
            if (downCandidate.element != nil) {
                [self drawHintForTravel:KSTTravelDown atPoint:downCandidate.element.position atScale:scale];
            }
            if (leftCandidate.element != nil) {
                [self drawHintForTravel:KSTTravelLeft atPoint:leftCandidate.element.position atScale:scale];
            }
            if (rightCandidate.element != nil) {
                [self drawHintForTravel:KSTTravelRight atPoint:rightCandidate.element.position atScale:scale];
            }
        }
    }
}

- (void)drawHintForTravel:(KSTTravel)travel atPoint:(CGPoint)point atScale:(CGFloat)scale {
    CGFloat offset;
    CGFloat headLength;
    CGFloat headSpan;
    
    switch (self.hintSize) {
    case 0:
        offset = 3 / scale;
        headLength = 5 / scale;
        headSpan = 2 / scale;
        break;
    case 2:
        offset = 7 / scale;
        headLength = 12 / scale;
        headSpan = 6 / scale;
        break;
    default:
        offset = 4 / scale;
        headLength = 7 / scale;
        headSpan = 3 / scale;
        break;
    }
    
    NSBezierPath *arrowHead = [NSBezierPath bezierPath];
    [arrowHead moveToPoint:NSMakePoint(-headLength, headSpan)];
    [arrowHead lineToPoint:NSZeroPoint];
    [arrowHead lineToPoint:NSMakePoint(-headLength, -headSpan)];
    [arrowHead closePath];
    
    NSAffineTransform *transform = [NSAffineTransform transform];
    
    switch (travel) {
    case KSTTravelUp:
        [transform translateXBy:point.x yBy:point.y - offset];
        [transform rotateByDegrees:90];
        break;
    case KSTTravelDown:
        [transform translateXBy:point.x yBy:point.y + offset];
        [transform rotateByDegrees:-90];
        break;
    case KSTTravelLeft:
        [transform translateXBy:point.x + offset yBy:point.y];
        [transform rotateByDegrees:-180];
        break;
    case KSTTravelRight:
        [transform translateXBy:point.x - offset yBy:point.y];
        break;
    }
    
    [arrowHead transformUsingAffineTransform:transform];
    
    [self.hintColor setFill];
    [arrowHead fill];
}

- (void)cycleCandidates {
    GSFont *font = ((GSApplication *)NSApp).currentFontDocument.font;
    
    if (font == nil) {
        return;
    }
    
    CGFloat upm = font.unitsPerEm;
    GSLayer *layer = self.editViewController.activeLayer;
    
    if (layer == nil) {
        return;
    }
    
    NSMutableOrderedSet<GSSelectableElement *> *selection = layer.selection;
    
    if (selection.count == 0) {
        return;
    }
    
    NSArray<KSTCandidate *> *upTargets = [self targetsForTravel:KSTTravelUp fromSelection:selection onLayer:layer atScale:upm];
    NSArray<KSTCandidate *> *downTargets = [self targetsForTravel:KSTTravelDown fromSelection:selection onLayer:layer atScale:upm];
    NSArray<KSTCandidate *> *leftTargets = [self targetsForTravel:KSTTravelLeft fromSelection:selection onLayer:layer atScale:upm];
    NSArray<KSTCandidate *> *rightTargets = [self targetsForTravel:KSTTravelRight fromSelection:selection onLayer:layer atScale:upm];
    
    for (int i = 0; i < selection.count; i++) {
        KSTCandidate *upCandidate = upTargets[i];
        KSTCandidate *downCandidate = downTargets[i];
        KSTCandidate *leftCandidate = leftTargets[i];
        KSTCandidate *rightCandidate = rightTargets[i];
        
        if (upCandidate.element != nil) {
            [self.skippedCandidates addObject:upCandidate.element];
        }
        if (downCandidate.element != nil) {
            [self.skippedCandidates addObject:downCandidate.element];
        }
        if (leftCandidate.element != nil) {
            [self.skippedCandidates addObject:leftCandidate.element];
        }
        if (rightCandidate.element != nil) {
            [self.skippedCandidates addObject:rightCandidate.element];
        }
    }
    
    BOOL hasUnskippedCandidates = NO;
    
    upTargets = [self targetsForTravel:KSTTravelUp fromSelection:selection onLayer:layer atScale:upm];
    downTargets = [self targetsForTravel:KSTTravelDown fromSelection:selection onLayer:layer atScale:upm];
    leftTargets = [self targetsForTravel:KSTTravelLeft fromSelection:selection onLayer:layer atScale:upm];
    rightTargets = [self targetsForTravel:KSTTravelRight fromSelection:selection onLayer:layer atScale:upm];
    
    for (int i = 0; i < selection.count; i++) {
        KSTCandidate *upCandidate = upTargets[i];
        KSTCandidate *downCandidate = downTargets[i];
        KSTCandidate *leftCandidate = leftTargets[i];
        KSTCandidate *rightCandidate = rightTargets[i];
        
        if (upCandidate.element != nil) {
            hasUnskippedCandidates |= YES;
            break;
        }
        if (downCandidate.element != nil) {
            hasUnskippedCandidates |= YES;
            break;
        }
        if (leftCandidate.element != nil) {
            hasUnskippedCandidates |= YES;
            break;
        }
        if (rightCandidate.element != nil) {
            hasUnskippedCandidates |= YES;
            break;
        }
    }
    
    if (!hasUnskippedCandidates) {
        // no more targets to cycle to: reset cycle
        [self resetSkippedCandidates];
    }
}

- (void)resetSkippedCandidates {
    [self.skippedCandidates removeAllObjects];
}

@end
