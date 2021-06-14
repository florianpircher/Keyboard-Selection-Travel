//
//  KSTController.h
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

#import <Cocoa/Cocoa.h>
#import <GlyphsCore/GSCallbackHandler.h>
#import <GlyphsCore/GSFont.h>
#import <GlyphsCore/GSLayer.h>
#import <GlyphsCore/GSProxyShapes.h>
#import <GlyphsCore/GSPath.h>
#import <GlyphsCore/GSAnchor.h>
#import <GlyphsCore/GSWindowControllerProtocol.h>
#import <GlyphsCore/GSGlyphViewControllerProtocol.h>
#import <GlyphsCore/GlyphsPluginProtocol.h>

NS_ASSUME_NONNULL_BEGIN

/// User default key whether to use Control-Shift instead of Control.
static NSString * const kUseAlternativeShortcutsKey = @"com.FlorianPircher.Keyboard-Selection-Travel.UseAlternativeShortcuts";
/// User default key for a set of tools class names for which this plugin will be disabled.
static NSString * const kIgnoreToolsKey = @"com.FlorianPircher.Keyboard-Selection-Travel.IgnoreTools";
/// User default key whether to show (`YES`) or hide (`NO`) hints.
static NSString * const kShowHintsKey = @"com.FlorianPircher.Keyboard-Selection-Travel.ShowHints";
/// User default key for the size of hints. -1: auto, 0: small, 1: regular, 3: large.
static NSString * const kHintSizeKey = @"com.FlorianPircher.Keyboard-Selection-Travel.HintSize";
/// User default preferences key for the hint color. The following colors are available: red = 0, orange = 1, brown = 2, yellow = 3, green = 4, blue = 7, purple = 8, pink = 9, gray = 10.
static NSString * const kHintColorKey = @"com.FlorianPircher.Keyboard-Selection-Travel.HintColor";

const NSUInteger kEventModifierKeyFlagsMask = NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand;

@interface GSApplication : NSApplication
@property (weak, nonatomic, nullable) GSDocument *currentFontDocument;
@end

@interface GSDocument : NSDocument
@property (nonatomic, retain) GSFont *font;
@property (weak, nonatomic, nullable) NSWindowController<GSWindowControllerProtocol> *windowController;
@end

@interface KSTController : NSObject<GlyphsPlugin>
@end

NS_ASSUME_NONNULL_END
