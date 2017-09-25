//
//  WZQSwizzler.m
//  libMainThreadChecker
//
//  Created by z on 2017/9/25.
//  Copyright © 2017年 SatanWoo. All rights reserved.
//

#import "WZQSwizzler.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import "imp_bridge.h"

#pragma mark - Private

bool wzq_swizzleMethod(Class cls, SEL origSEL)
{
    Method origMethod = class_getInstanceMethod(cls, origSEL);
    if (!origMethod) return false;
    
    const char *origin_type = method_getTypeEncoding(origMethod);
    IMP originIMP = method_getImplementation(origMethod);
    
    Dl_info info;
    dladdr(originIMP, &info);
    
    NSString *binaryName = [NSString stringWithUTF8String:info.dli_fname];
    if (![binaryName hasSuffix:@"UIKit"]) return NO;
    
    SEL forwardingSEL = NSSelectorFromString([NSString stringWithFormat:@"__WZQMessageTemporary_%@_%@",
                                              NSStringFromClass(cls),
                                              NSStringFromSelector(origSEL)]);
    
    IMP forwardingIMP = imp_selector_bridge(forwardingSEL);
    
    method_setImplementation(origMethod, forwardingIMP);
    
    SEL newSelector = NSSelectorFromString([NSString stringWithFormat:@"__WZQMessageFinal_%@_%@",
                                            NSStringFromClass(cls),
                                            NSStringFromSelector(origSEL)]);
    
    
    
    return class_addMethod(cls, newSelector, originIMP, origin_type);
}


BOOL wzq_in_skipped_list(NSString *methodName) {
    static NSArray *defaultBlackList = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultBlackList = @[/*UIViewController的:*/
                             @".cxx_destruct",
                             @"dealloc",
                             @"_isDeallocating",
                             @"release",
                             @"autorelease",
                             @"retain",
                             @"Retain",
                             @"_tryRetain",
                             @"copy",
                             /*UIView的:*/
                             @"nsis_descriptionOfVariable:",
                             /*NSObject的:*/
                             @"respondsToSelector:",
                             @"class",
                             @"methodSignatureForSelector:",
                             @"allowsWeakReference",
                             @"retainWeakReference",
                             @"init",
                             @"forwardInvocation:",
                             @"description",
                             @"debugDescription",
                             @"self",
                             @"beginBackgroundTaskWithExpirationHandler:",
                             @"beginBackgroundTaskWithName:expirationHandler:",
                             @"endBackgroundTask:",
                             @"lockFocus",
                             @"lockFocusIfCanDraw",
                             @"lockFocusIfCanDraw"
                             ];
    });
    return ([defaultBlackList containsObject:methodName]);
}

bool should_skip_swizzle_this_method(NSString *selName)
{
    return wzq_in_skipped_list(selName);
}

#pragma mark - Public

void _addSwizzle(Class cls)
{
#ifndef DEBUG
    return;
#endif
    
    unsigned int method_count = 0;
    Method *methods = class_copyMethodList(cls, &method_count);
    
    for (unsigned int i = 0; i < method_count; i++) {
        Method m = *(methods + i);
        SEL sel = method_getName(m);
        
        if (should_skip_swizzle_this_method(NSStringFromSelector(sel))) {
            continue;
        }
        
        bool ret = wzq_swizzleMethod(cls, sel);
        if (!ret) {
            assert(false);
        }
    }
    
    free(methods);
    methods = NULL;
}



