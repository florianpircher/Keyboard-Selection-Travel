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
#import <GlyphsCore/GSFont.h>
#import <GlyphsCore/GSLayer.h>
#import <GlyphsCore/GSProxyShapes.h>
#import <GlyphsCore/GSPath.h>
#import <GlyphsCore/GSAnchor.h>
#import <GlyphsCore/GSWindowControllerProtocol.h>
#import <GlyphsCore/GSGlyphViewControllerProtocol.h>
#import <GlyphsCore/GlyphsPluginProtocol.h>

NS_ASSUME_NONNULL_BEGIN

/// User default preferences key whether to use Control-Shift instead of Control.
static NSString * const kUseAlternativeShortcutsKey = @"com.FlorianPircher.Keyboard-Selection-Travel.UseAlternativeShortcuts";
/// Set of tools class names for which this plugin will be disabled.
static NSString * const kIgnoreToolsKey = @"com.FlorianPircher.Keyboard-Selection-Travel.IgnoreTools";

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
