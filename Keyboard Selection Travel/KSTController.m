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

typedef NS_ENUM(NSUInteger, KSTTravel) {
    KSTTravelUp,
    KSTTravelDown,
    KSTTravelLeft,
    KSTTravelRight,
};

@interface KSTController ()
@property (nonatomic, retain) NSSet *ignoreToolClassNameSet;
@property (nonatomic, assign) BOOL travelHintsActive;
@end

@implementation KSTController

+ (void)initialize
{
    if (self == [KSTController class]) {
        [NSUserDefaults.standardUserDefaults registerDefaults:@{
            kUseAlternativeShortcutsKey: @NO,
            kIgnoreToolsKey: @[@"GlyphsToolText"],
        }];
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
    NSArray<NSString *> *ignoreToolClassNames = [NSUserDefaults.standardUserDefaults arrayForKey:kIgnoreToolsKey];
    NSMutableSet<NSString *> *ignoreToolClassNameSet = [NSMutableSet new];
    
    if (ignoreToolClassNames != nil) {
        for (NSString *className in ignoreToolClassNames) {
            if ([className isKindOfClass:[NSString class]]) {
                [ignoreToolClassNameSet addObject:className];
            }
        }
    }
    
    self.ignoreToolClassNameSet = ignoreToolClassNameSet;
    
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown|NSEventMaskFlagsChanged handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        NSUInteger flags = event.modifierFlags & kEventModifierKeyFlagsMask;
        
        BOOL isTravel;
        
        if ([NSUserDefaults.standardUserDefaults boolForKey:kUseAlternativeShortcutsKey]) {
            // alternative shortcuts are Control-Shift with the Up/Down/Left/Right arow keys
            isTravel = flags == (NSEventModifierFlagControl|NSEventModifierFlagShift);
        } else {
            // standard shortcuts are Control with the Up/Down/Left/Right arow keys
            isTravel = flags == NSEventModifierFlagControl;
        }
        
        if (event.type == NSEventTypeFlagsChanged) {
            self.travelHintsActive = isTravel;
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
    
    [GSCallbackHandler addCallback:self forOperation:GSDrawBackgroundCallbackName];
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

- (void)drawBackgroundForLayer:(GSLayer *)layer options:(NSDictionary *)options {
    if (self.travelHintsActive && self.travelActive) {
        CGFloat scale = [options[@"Scale"] doubleValue];
        CGFloat upm = ((GSApplication *)NSApp).currentFontDocument.font.unitsPerEm;
        GSLayer *layer = self.editViewController.activeLayer;
        NSMutableOrderedSet<GSSelectableElement *> *selection = layer.selection;
        
        NSArray<KSTCandidate *> *upTargets = [self targetsForTravel:KSTTravelUp fromSelection:selection onLayer:layer atScale:upm];
        NSArray<KSTCandidate *> *downTargets = [self targetsForTravel:KSTTravelDown fromSelection:selection onLayer:layer atScale:upm];
        NSArray<KSTCandidate *> *leftTargets = [self targetsForTravel:KSTTravelLeft fromSelection:selection onLayer:layer atScale:upm];
        NSArray<KSTCandidate *> *rightTargets = [self targetsForTravel:KSTTravelRight fromSelection:selection onLayer:layer atScale:upm];
        
        for (int i = 0; i < selection.count; i++) {
            GSSelectableElement *origin = selection[i];
            
            KSTCandidate *upCandidate = upTargets[i];
            KSTCandidate *downCandidate = downTargets[i];
            KSTCandidate *leftCandidate = leftTargets[i];
            KSTCandidate *rightCandidate = rightTargets[i];
            
            if (upCandidate.element != nil) {
                [self drawHintFromStart:origin.position toEnd:upCandidate.element.position atScale:scale];
            }
            if (downCandidate.element != nil) {
                [self drawHintFromStart:origin.position toEnd:downCandidate.element.position atScale:scale];
            }
            if (leftCandidate.element != nil) {
                [self drawHintFromStart:origin.position toEnd:leftCandidate.element.position atScale:scale];
            }
            if (rightCandidate.element != nil) {
                [self drawHintFromStart:origin.position toEnd:rightCandidate.element.position atScale:scale];
            }
        }
    }
}

- (void)drawHintFromStart:(CGPoint)start toEnd:(CGPoint)end atScale:(CGFloat)scale {
    CGFloat length = hypot(end.x - start.x, end.y - start.y);
    CGFloat headOffset = 5 / scale;
    CGFloat tailLength = length - (7 / scale) - headOffset;
    CGFloat headWidth = 6 / scale;
    
    NSBezierPath *arrowHead = [NSBezierPath bezierPath];
    [arrowHead moveToPoint:NSMakePoint(tailLength, headWidth / 2)];
    [arrowHead lineToPoint:NSMakePoint(length - headOffset, 0)];
    [arrowHead lineToPoint:NSMakePoint(tailLength, -headWidth / 2)];
    [arrowHead closePath];
    
    CGFloat cosine = (end.x - start.x) / length;
    CGFloat sine = (end.y - start.y) / length;
    NSAffineTransform *transform = [NSAffineTransform transform];
    NSAffineTransformStruct transformStruct;
    transformStruct.m11 = cosine;
    transformStruct.m12 = sine;
    transformStruct.m21 = -sine;
    transformStruct.m22 = cosine;
    transformStruct.tX = start.x;
    transformStruct.tY = start.y;
    [transform setTransformStruct: transformStruct];
    [arrowHead transformUsingAffineTransform:transform];
    
    [NSColor.systemGrayColor set];
    [arrowHead fill];
    
    if (tailLength > 0) {
        NSBezierPath *arrowTail = [NSBezierPath bezierPath];
        [arrowTail moveToPoint:NSMakePoint(1 / scale, 0)];
        [arrowTail lineToPoint:NSMakePoint(tailLength, 0)];
        [arrowTail setLineWidth:1 / scale];
        [arrowTail setLineCapStyle:NSLineCapStyleRound];
        CGFloat dashPattern[] = { 2.5 / scale, 4 / scale };
        [arrowTail transformUsingAffineTransform:transform];
        
        [arrowTail setLineDash:dashPattern count:2 phase:0];
        [[NSColor.systemGrayColor colorWithAlphaComponent:0.2] set];
        [arrowTail stroke];
    }
}

@end
