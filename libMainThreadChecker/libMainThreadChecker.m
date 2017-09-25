//
//  libMainThreadChecker.m
//  libMainThreadChecker
//
//  Created by z on 2017/9/25.
//  Copyright © 2017年 SatanWoo. All rights reserved.
//

#import "libMainThreadChecker.h"
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "WZQSwizzler.h"

#ifdef __LP64__
typedef struct mach_header_64 wzq_macho_header;
#else
typedef struct mach_header wzq_macho_header;
#endif

void library_initializer()
{
    uint32_t image_count = _dyld_image_count();
    for (uint32_t idx = 0; idx < image_count; idx++) {
        const char *binary_name = _dyld_get_image_name(idx);
        NSString *binaryName = [NSString stringWithUTF8String:binary_name];
        
        if ([binaryName hasSuffix:@"UIKit"]) {
            unsigned int count;
            const char **uikit_classes;
            Dl_info info;
            
            const wzq_macho_header *header = (const wzq_macho_header *)_dyld_get_image_header(idx);
            dladdr(header, &info);
            
            uikit_classes = objc_copyClassNamesForImage(info.dli_fname, &count);
            
            for (unsigned int i = 0; i < count; i++) {
                const char *class_name = (const char *)uikit_classes[i];
                
                NSString *className = [NSString stringWithUTF8String:class_name];
                if ([className hasPrefix:@"_"]) continue;
                
                Class cls = objc_getClass(class_name);
                Class superCls = cls;
                
                BOOL isInheritedSubClass = NO;
                while (superCls != [NSObject class]) {
                    if (superCls == [UIView class] || superCls == [UIApplication class]) {
                        isInheritedSubClass = YES;
                        break;
                    }
                    superCls = class_getSuperclass(superCls);
                }
                
                if (isInheritedSubClass) {
                    _addSwizzle(cls);
                }
            }
        }
    }
}

