//
//  KeyboardSelectionTravel.h
//  Keyboard Selection Travel
//
//  Created by Florian Pircher on 2021-03-13.
//

#import <Cocoa/Cocoa.h>
#import <GlyphsCore/GSFont.h>
#import <GlyphsCore/GSLayer.h>
#import <GlyphsCore/GSProxyShapes.h>
#import <GlyphsCore/GSPath.h>
#import <GlyphsCore/GSWindowControllerProtocol.h>
#import <GlyphsCore/GSGlyphViewControllerProtocol.h>
#import <GlyphsCore/GlyphsPluginProtocol.h>

NS_ASSUME_NONNULL_BEGIN

const NSUInteger kEventModifierKeyFlagsMask = NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand;

@interface GSApplication : NSApplication
@property (weak, nonatomic, nullable) GSDocument *currentFontDocument;
@end

@interface GSDocument : NSDocument
@property (nonatomic, retain) GSFont *font;
@property (weak, nonatomic, nullable) NSWindowController<GSWindowControllerProtocol> *windowController;
@end

@interface KeyboardSelectionTravel : NSObject<GlyphsPlugin>

@end

NS_ASSUME_NONNULL_END
