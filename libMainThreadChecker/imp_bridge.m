//
//  imp_bridge.m
//  libMainThreadChecker
//
//  Created by z on 2017/9/25.
//  Copyright © 2017年 SatanWoo. All rights reserved.
//


#import "imp_bridge.h"
#import <objc/message.h>
#import <AssertMacros.h>

#import <mach/vm_types.h>
#import <mach/vm_map.h>
#import <mach/mach_init.h>

FOUNDATION_EXTERN id wzq_forwarding_bridge_page(id, SEL);

typedef struct {
    SEL selector;
} WZQBridgeBlock;

#if defined(__arm64__)
typedef int32_t WZQForwardingBridgeEntryPointBlock[2];
static const int32_t WZQForwardingBridgeInstructionCount = 6;
#else
#error 还没支持，不想支持了
#endif

// 老子printf调试的
static const size_t numberOfBridgePerPage = (16384 - WZQForwardingBridgeInstructionCount * sizeof(int32_t)) / sizeof(WZQForwardingBridgeEntryPointBlock);

typedef struct {
    union {
        struct {
            IMP msgSend;
            int32_t nextAvailableIndex;
        };
        int32_t bridgeSize[WZQForwardingBridgeInstructionCount];
    };

    WZQBridgeBlock bridgeData[numberOfBridgePerPage];

    int32_t bridgeInstructions[WZQForwardingBridgeInstructionCount];
    WZQForwardingBridgeEntryPointBlock bridgeEntryPoints[numberOfBridgePerPage];
} WZQBridgePage;


static WZQBridgePage *WZQBridgePageAlloc()
{
    vm_address_t bridgeTemplatePage = (vm_address_t)&wzq_forwarding_bridge_page;

    vm_address_t newBridgePage = 0;
    kern_return_t kernReturn = KERN_SUCCESS;

    kernReturn = vm_allocate(mach_task_self(), &newBridgePage, PAGE_SIZE * 2, VM_FLAGS_ANYWHERE);
    NSCAssert1(kernReturn == KERN_SUCCESS, @"vm_allocate failed", kernReturn);

    vm_address_t new_bridge_page = newBridgePage + PAGE_SIZE;
    kernReturn = vm_deallocate(mach_task_self(), new_bridge_page, PAGE_SIZE);
    NSCAssert1(kernReturn == KERN_SUCCESS, @"vm_deallocate failed", kernReturn);

    vm_prot_t cur_protection, max_protection;
    kernReturn = vm_remap(mach_task_self(), &new_bridge_page, PAGE_SIZE, 0, 0, mach_task_self(), bridgeTemplatePage, FALSE, &cur_protection, &max_protection, VM_INHERIT_SHARE);
    NSCAssert1(kernReturn == KERN_SUCCESS, @"vm_remap failed", kernReturn);

    return (void *)newBridgePage;
}

static WZQBridgePage *nextBridgePage()
{
    static NSMutableArray *normalTrampolinePages = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        normalTrampolinePages = [NSMutableArray array];
    });

    NSMutableArray *thisArray = normalTrampolinePages;

    WZQBridgePage *bridgePage = [thisArray.lastObject pointerValue];

    if (!bridgePage) {
        bridgePage = WZQBridgePageAlloc();
        [thisArray addObject:[NSValue valueWithPointer:bridgePage]];
    }

    if (bridgePage->nextAvailableIndex == numberOfBridgePerPage) {
        bridgePage = WZQBridgePageAlloc();
        [thisArray addObject:[NSValue valueWithPointer:bridgePage]];
    }

    bridgePage->msgSend = objc_msgSend;
    return bridgePage;
}

IMP imp_selector_bridge(SEL forwardingSelector)
{
    WZQBridgePage *dataPageLayout = nextBridgePage();

    int32_t nextAvailableIndex = dataPageLayout->nextAvailableIndex;

    dataPageLayout->bridgeData[nextAvailableIndex].selector = forwardingSelector;
    dataPageLayout->nextAvailableIndex++;

    IMP implementation = (IMP)&dataPageLayout->bridgeEntryPoints[nextAvailableIndex];

    return implementation;
}
