//
//  Keyboard Selection Travel.m
//  Keyboard Selection Travel
//
//  Created by Florian Pircher on 2021-03-13.
//

#import "KeyboardSelectionTravel.h"
#import "KSTCandidate.h"

typedef NS_ENUM(NSUInteger, KSTTravel) {
    KSTTravelUp,
    KSTTravelDown,
    KSTTravelLeft,
    KSTTravelRight,
};

@implementation KeyboardSelectionTravel

- (NSUInteger)interfaceVersion {
    return 1;
}

- (void)loadPlugin {
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        NSUInteger flags = [event modifierFlags] & kEventModifierKeyFlagsMask;
        BOOL isTravel = flags == NSEventModifierFlagControl;
        BOOL isExpandingTravel = flags == (NSEventModifierFlagControl|NSEventModifierFlagShift);
        
        if (isTravel || isExpandingTravel) {
            switch ([[event charactersIgnoringModifiers] characterAtIndex:0]) {
            case NSUpArrowFunctionKey:
                [self travel:KSTTravelUp];
                return nil;
            case NSDownArrowFunctionKey:
                [self travel:KSTTravelDown];
                return nil;
            case NSLeftArrowFunctionKey:
                [self travel:KSTTravelLeft];
                return nil;
            case NSRightArrowFunctionKey:
                [self travel:KSTTravelRight];
                return nil;
            }
        }
        
        return event;
    }];
}

- (void)travel:(KSTTravel)travel {
    GSDocument *document = [(GSApplication *)NSApp currentFontDocument];
    GSFont *font = [document font];
    
    if (font == nil) {
        return;
    }
    
    CGFloat upm = [font unitsPerEm];
    NSWindowController<GSWindowControllerProtocol> *windowController = [document windowController];
    NSViewController<GSGlyphEditViewControllerProtocol> *editViewController = [windowController activeEditViewController];
    GSLayer *activeLayer = [editViewController activeLayer];
    NSMutableOrderedSet<GSSelectableElement*> *selection = [activeLayer selection];
    
    if (selection == nil) {
        return;
    }
    
    NSMutableArray<KSTCandidate *> *candidates = [NSMutableArray arrayWithCapacity:[selection count]];
    
    for (int i = 0; i < [selection count]; i++) {
        KSTCandidate *candidate = [KSTCandidate new];
        [candidate setDistance:CGFLOAT_MAX];
        [candidate setElement:nil];
        [candidates addObject:candidate];
    }
    
    for (GSPath *path in [activeLayer paths]) {
        for (GSNode *node in [path nodes]) {
            for (int i = 0; i < [selection count]; i++) {
                GSShape *s = (GSShape *)[selection objectAtIndex:i];
                
                if ([node isEqualTo:s]) {
                    continue;
                }
                
                CGFloat distance = [self distanceFrom:s to:node atScale:upm withTravel:travel];
                KSTCandidate *c = [candidates objectAtIndex:i];
                
                if (distance < [c distance]) {
                    [c setDistance:distance];
                    [c setElement:node];
                }
            }
        }
    }
    
    NSMutableOrderedSet<GSSelectableElement *> *newSelection = [NSMutableOrderedSet new];
    
    for (int i = 0; i < [candidates count]; i++) {
        KSTCandidate *c = [candidates objectAtIndex:i];
        
        GSSelectableElement *element;
        
        if ([c element] == nil) {
            element = [selection objectAtIndex:i];
        } else {
            element = [c element];
        }
        
        [newSelection addObject:element];
    }
    
    [activeLayer setSelection:newSelection];
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
    CGFloat dp = isVertical ? dy : dx;
    CGFloat ds = isVertical ? dx : dy;
    
    CGFloat distance = -atan2(dp, ds / 4) + dp + ds;
    
    return distance;
}

@end
