//
//  zhThemePicker.m
//  <https://github.com/snail-z/ThemeManager>
//
//  Created by zhanghao on 2017/5/22.
//  Copyright © 2017年 snail-z. All rights reserved.
//

#import "zhThemePicker.h"

@implementation zhThemePicker (Helper)

+ (NSArray *)preferredScales {
    static NSArray *scales;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat screenScale = [UIScreen mainScreen].scale;
        if (screenScale <= 1) {
            scales = @[@1, @2, @3];
        } else if (screenScale <= 2) {
            scales = @[@2, @3, @1];
        } else {
            scales = @[@3, @2, @1];
        }
    });
    return scales;
}

+ (NSString *)stringByAppendingNameScale:(CGFloat)scale forString:(NSString *)string {
    if (fabs(scale - 1) <= __FLT_EPSILON__ || string.length == 0 || [string hasSuffix:@"/"]) return string.copy;
    return [string stringByAppendingFormat:@"@%@x", @(scale)];
}

+ (NSString *)stringByAppendingPathScale:(CGFloat)scale forString:(NSString *)string {
    if (fabs(scale - 1) <= __FLT_EPSILON__ || string.length == 0 || [string hasSuffix:@"/"]) return string.copy;
    NSString *ext = string.pathExtension;
    NSRange extRange = NSMakeRange(string.length - ext.length, 0);
    if (ext.length > 0) extRange.location -= 1;
    NSString *scaleStr = [NSString stringWithFormat:@"@%@x", @(scale)];
    return [string stringByReplacingCharactersInRange:extRange withString:scaleStr];
}

+ (NSString *)pathForScaledResource:(NSString *)name ofType:(NSString *)ext inBundle:(NSBundle *)bundle {
    if (name.length == 0) return nil;
    if ([name hasSuffix:@"/"]) return [bundle pathForResource:name ofType:ext];
    NSString *path = nil;
    NSArray *scales = [self preferredScales];
    for (int s = 0; s < scales.count; s++) {
        CGFloat scale = ((NSNumber *)scales[s]).floatValue;
        NSString *scaledName = ext.length ? [self stringByAppendingNameScale:scale forString:name]
        : [self stringByAppendingPathScale:scale forString:name];
        path = [bundle pathForResource:scaledName ofType:ext];
        if (path) break;
    }
    return path;
}

+ (UIImage *)imageNamed:(NSString *)name from:(id)from { // bundle / path
    if ([from isKindOfClass:[NSBundle class]]) {
        NSString *ext = name.pathExtension;
        if (ext.length == 0) ext = @"png";
        else name = name.stringByDeletingPathExtension;
        NSString *path = [self pathForScaledResource:name ofType:ext inBundle:from];
        return [UIImage imageWithContentsOfFile:path]; //  cache todo...
    } else if ([from isKindOfClass:[NSString class]]) {
        NSString *fullPath = [from stringByAppendingPathComponent:name];
        return [UIImage imageWithContentsOfFile:fullPath];
    } else return nil;
}

+ (UIColor *)colorFromHexString:(NSString *)hexString {
    if (!hexString) return nil;
    NSString *hex = [NSString stringWithString:hexString];
    if ([hex hasPrefix:@"#"]) hex = [hex substringFromIndex:1];
    if (hex.length == 6) {
        hex = [hex stringByAppendingString:@"FF"];
    } else if (hex.length != 8) return nil;
    uint32_t rgba;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    [scanner scanHexInt:&rgba];
    return [UIColor colorWithRed:((rgba >> 24)&0xFF) / 255. green:((rgba >> 16)&0xFF) / 255. blue:((rgba >> 8)&0xFF) / 255. alpha:(rgba&0xFF) / 255.];;
}

+ (UIColor *)checkColor:(id)obj {
    if ([obj isKindOfClass:[NSString class]]) {
        return [self colorFromHexString:obj];
    } else if ([obj isKindOfClass:[UIColor class]]) {
        return (UIColor *)obj;
    } return nil;
}

+ (UIImage *)checkImage:(id)obj {
    if ([obj isKindOfClass:[NSString class]]) {
        return [UIImage imageNamed:(NSString *)obj];
    } else if ([obj isKindOfClass:[UIImage class]]) {
        return (UIImage *)obj;
    } else if ([obj isKindOfClass:[NSData class]]) {
        return [UIImage imageWithData:(NSData *)obj];
    } else return nil;
}

@end


@interface zhThemePicker ()

@property (nonatomic, strong, readonly) NSString *pkey;
@property (nonatomic, strong, readonly) NSDictionary<NSString *, id> *pDict;

@end

@implementation zhThemePicker

- (instancetype)initWithKey:(NSString *)key
                       dict:(NSDictionary *)dict
                  valueType:(zhThemeValueType)valueType {
    if (self = [super init]) {
        _pkey = key;
        _pDict = dict;
        _valueType = valueType;
    }
    return self;
}

+ (instancetype)pickerWithKey:(NSString *)pKey {
    NSAssert1(0, @"%@ This method should be handed to the subclass call!", NSStringFromSelector(_cmd));
    return [[self alloc] init];
}

+ (instancetype)pickerWithDictionary:(NSDictionary *)pDict {
    NSAssert1(0, @"%@ This method should be handed to the subclass call!", NSStringFromSelector(_cmd));
    return [[self alloc] init];
}

@end

@implementation zhThemeColorPicker

+ (instancetype)pickerWithKey:(NSString *)pKey {
    return [[self alloc] initWithKey:pKey dict:nil valueType:zhThemeValueTypeColor];
}

+ (instancetype)pickerWithDictionary:(NSDictionary *)pDict {
    return [[self alloc] initWithKey:nil dict:pDict valueType:zhThemeValueTypeColor];
}

- (zhThemeColorPicker *(^)(BOOL))animated {
    return ^id(BOOL isAnimated) {
        _isAnimated = isAnimated;
        return self;
    };
}

- (UIColor *)color {
    NSString *styleKey = ThemeManager.currentStyle;

    if (self.pDict) {
        if (![self.pDict.allKeys containsObject:styleKey]) {
            [ThemeManager debugLog:@"Not found key - \"%@\" in dictionary. \n%@", styleKey, self.pDict];
            return nil;
        }
        return [zhThemePicker checkColor:self.pDict[styleKey]];
    }
    
    NSDictionary<NSString *, NSDictionary *> *libraries = ThemeManager.colorLibraries;
    if (![libraries.allKeys containsObject:styleKey]) {
         [ThemeManager debugLog:@"Not found key - \"%@\". Please check if your configuration file is correct! \n%@ ", styleKey, ThemeManager.currentColorFilePath];
        return nil;
    }
    NSDictionary *dictionary = libraries[styleKey];
    if (![dictionary.allKeys containsObject:self.pkey]) {
        [ThemeManager debugLog:@"Not found key - \"%@\" in \"%@\" theme style. Please check if your configuration file is correct! \n%@ ", self.pkey, styleKey, ThemeManager.currentColorFilePath];
        return nil;
    }
    NSString *value = dictionary[self.pkey];
    NSParameterAssert([value isKindOfClass:[NSString class]]);
    return [zhThemePicker checkColor:value];
}

@end

@implementation zhThemeImagePicker

- (instancetype)initWithKey:(NSString *)key
                       dict:(NSDictionary *)dict
                  valueType:(zhThemeValueType)valueType {
    _imageRenderingMode = -1;
    return [super initWithKey:key dict:dict valueType:valueType];
}

+ (instancetype)pickerWithKey:(NSString *)pKey {
    return [[self alloc] initWithKey:pKey dict:nil valueType:zhThemeValueTypeImage];
}

+ (instancetype)pickerWithDictionary:(NSDictionary *)pDict {
    return [[self alloc] initWithKey:nil dict:pDict valueType:zhThemeValueTypeImage];
}

- (zhThemeImagePicker *(^)(UIImageRenderingMode))renderingMode {
    return ^id(UIImageRenderingMode imageRenderingMode) {
        _imageRenderingMode = imageRenderingMode;
        return self;
    };
}

- (zhThemeImagePicker *(^)(UIEdgeInsets))resizableCapInsets {
    return ^id(UIEdgeInsets imageCapInsets) {
        _imageCapInsets = imageCapInsets;
        return self;
    };
}

- (UIImage *)image {
    UIImage* (^callback)(id) = ^(id unconfirmed) {
        UIImage *value = nil;
        NSString *sources = ThemeManager.pathOfImageSources;
        if (sources) {
            value = [zhThemePicker imageNamed:unconfirmed from:sources];
        }
        else {
            value = [zhThemePicker checkImage:unconfirmed];
        }
        if (value) {
            if (!UIEdgeInsetsEqualToEdgeInsets(UIEdgeInsetsZero, _imageCapInsets)) {
                value = [value resizableImageWithCapInsets:_imageCapInsets];
            }
            if (_imageRenderingMode >= 0) {
                value = [value imageWithRenderingMode:_imageRenderingMode];
            }
        }
        return value;
    };
    
    NSString *styleKey = ThemeManager.currentStyle;
    
    if (self.pDict) {
        if (![self.pDict.allKeys containsObject:styleKey]) {
            [ThemeManager debugLog:@"Not found key - \"%@\" in dictionary. \n%@", styleKey, self.pDict];
            return nil;
        }
        return callback(self.pDict[styleKey]);
    }
    
    NSDictionary<NSString *, NSDictionary *> *libraries = ThemeManager.imageLibraries;
    if (![libraries.allKeys containsObject:styleKey]) {
        [ThemeManager debugLog:@"Not found key - \"%@\". Please check if your configuration file is correct! \n%@ ", styleKey, ThemeManager.currentImageFilePath];
        return nil;
    }
    NSDictionary *dictionary = libraries[styleKey];
    if (![dictionary.allKeys containsObject:self.pkey]) {
        [ThemeManager debugLog:@"Not found key - \"%@\" in \"%@\" theme style. Please check if your configuration file is correct! \n%@ ", self.pkey, styleKey, ThemeManager.currentImageFilePath];
        return nil;
    }
    NSString *value = dictionary[self.pkey];
    NSParameterAssert([value isKindOfClass:[NSString class]]);
    if ([value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length) {
        return callback(value);
    }
    return nil;
}

@end

@implementation zhThemeFontPicker

+ (instancetype)pickerWithDictionary:(NSDictionary *)pDict {
    return [[self alloc] initWithKey:nil dict:pDict valueType:zhThemeValueTypeFont];
}

- (UIFont *)font {
    NSString *styleKey = ThemeManager.currentStyle;
    if (self.pDict) {
        if (![self.pDict.allKeys containsObject:styleKey]) {
            [ThemeManager debugLog:@"Not found key - \"%@\" in dictionary. \n%@", styleKey, self.pDict];
            return nil;
        }
        id obj = self.pDict[styleKey];
        if ([obj isKindOfClass:[UIFont class]]) return (UIFont *)obj;
    }
    return nil;
}

@end

@implementation zhThemeTextPicker

+ (instancetype)pickerWithDictionary:(NSDictionary *)pDict {
    return [[self alloc] initWithKey:nil dict:pDict valueType:zhThemeValueTypeText];
}

- (NSString *)text {
    NSString *styleKey = ThemeManager.currentStyle;
    if (self.pDict) {
        if (![self.pDict.allKeys containsObject:styleKey]) {
            [ThemeManager debugLog:@"Not found key - \"%@\" in dictionary. \n%@", styleKey, self.pDict];
            return nil;
        }
        id obj = self.pDict[styleKey];
        if ([obj isKindOfClass:[NSString class]]) return (NSString *)obj;
    }
    return nil;
}

@end

@implementation zhThemeNumberPicker

+ (instancetype)pickerWithDictionary:(NSDictionary *)pDict {
    return [[self alloc] initWithKey:nil dict:pDict valueType:zhThemeValueTypeNumber];
}

- (NSNumber *)number {
    NSString *styleKey = ThemeManager.currentStyle;
    if (self.pDict) {
        if (![self.pDict.allKeys containsObject:styleKey]) {
            [ThemeManager debugLog:@"Not found key - \"%@\" in dictionary. \n%@", styleKey, self.pDict];
            return nil;
        }
        id obj = self.pDict[styleKey];
        if ([obj isKindOfClass:[NSNumber class]]) return (NSNumber *)obj;
    }
    return nil;
}

@end
