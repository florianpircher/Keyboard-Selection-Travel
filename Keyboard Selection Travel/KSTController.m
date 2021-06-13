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
    
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        NSUInteger flags = event.modifierFlags & kEventModifierKeyFlagsMask;
        
        // standard shortcuts are Control with the Up/Down/Left/Right arow keys
        BOOL isTravel = flags == NSEventModifierFlagControl;
        
        // in case the alternative shortcuts are enabled, check for them, too
        if ([NSUserDefaults.standardUserDefaults boolForKey:kUseAlternativeShortcutsKey]) {
            // alternative shortcuts are Control-Shift with the Up/Down/Left/Right arow keys
            isTravel |= flags == (NSEventModifierFlagControl|NSEventModifierFlagShift);
        }
        
        if (isTravel) {
            unichar character = [event.charactersIgnoringModifiers characterAtIndex:0];
            BOOL didTravel = [self travelForCharacter:character];
            
            if (didTravel) {
                return nil;
            }
        }
        
        return event;
    }];
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
    
    CGFloat upm = font.unitsPerEm;
    NSViewController<GSGlyphEditViewControllerProtocol> *editViewController = windowController.activeEditViewController;
    GSLayer *activeLayer = editViewController.activeLayer;
    NSMutableOrderedSet<GSSelectableElement *> *selection = activeLayer.selection;
    
    if (selection == nil) {
        return NO;
    }
    
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
    for (GSPath *path in activeLayer.paths) {
        for (GSNode *node in path.nodes) {
            for (int i = 0; i < selection.count; i++) {
                GSShape *s = (GSShape *)[selection objectAtIndex:i];
                
                if ([node isEqualTo:s]) {
                    // selected points are already stored in `candidates`
                    continue;
                }
                
                CGFloat distance = [self distanceFrom:s to:node atScale:upm withTravel:travel];
                KSTCandidate *c = [candidates objectAtIndex:i];
                
                if (distance < c.distance) {
                    c.distance = distance;
                    c.element = node;
                }
            }
        }
    }
    
    // evaluate all anchors
    for (NSString *anchorName in activeLayer.anchors) {
        GSAnchor *anchor = [activeLayer.anchors objectForKey:anchorName];
        
        for (int i = 0; i < selection.count; i++) {
            GSShape *s = (GSShape *)[selection objectAtIndex:i];
            
            if ([anchor isEqualTo:s]) {
                // selected points are already stored in `candidates`
                continue;
            }
            
            CGFloat distance = [self distanceFrom:s to:anchor atScale:upm withTravel:travel];
            KSTCandidate *c = [candidates objectAtIndex:i];
            
            if (distance < c.distance) {
                c.distance = distance;
                c.element = anchor;
            }
        }
    }
    
    // the elements to select
    NSMutableOrderedSet<GSSelectableElement *> *newSelection = [NSMutableOrderedSet new];
    
    for (int i = 0; i < candidates.count; i++) {
        KSTCandidate *c = [candidates objectAtIndex:i];
        
        GSSelectableElement *element;
        
        if (c.element == nil) {
            // no target was found, keep current selection
            element = [selection objectAtIndex:i];
        } else {
            // select the new target element
            element = c.element;
        }
        
        [newSelection addObject:element];
    }
    
    [activeLayer setSelection:newSelection];
    
    return YES;
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

@end
