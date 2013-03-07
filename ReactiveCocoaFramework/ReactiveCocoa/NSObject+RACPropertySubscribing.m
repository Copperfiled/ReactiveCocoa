//
//  NSObject+RACPropertySubscribing.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACPropertySubscribing.h"
#import "NSObject+RACKVOWrapper.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import "EXTScope.h"
#import "RACKVOTrampoline.h"
#import "RACCompoundDisposable.h"
#import <objc/runtime.h>

static const void *RACObjectCompoundDisposable = &RACObjectCompoundDisposable;
static const void *RACObjectScopedDisposable = &RACObjectScopedDisposable;

@implementation NSObject (RACPropertySubscribing)

+ (RACSignal *)rac_signalFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer {
	@unsafeify(observer, object);
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		@strongify(observer, object);
		RACKVOTrampoline *KVOTrampoline = [object rac_addObserver:observer forKeyPath:keyPath options:0 block:^(id target, id observer, NSDictionary *change) {
			[subscriber sendNext:[target valueForKeyPath:keyPath]];
		}];

		RACDisposable *KVODisposable = [RACDisposable disposableWithBlock:^{
			[KVOTrampoline stopObserving];
		}];

		@weakify(subscriber);
		RACDisposable *deallocDisposable = [RACDisposable disposableWithBlock:^{
			@strongify(subscriber);
			[KVODisposable dispose];
			[subscriber sendCompleted];
		}];

		[observer rac_addDeallocDisposable:deallocDisposable];
		[object rac_addDeallocDisposable:deallocDisposable];

		RACCompoundDisposable *observerDisposable = observer.rac_deallocDisposable;
		RACCompoundDisposable *objectDisposable = object.rac_deallocDisposable;
		@weakify(observerDisposable, objectDisposable, deallocDisposable);
		return [RACDisposable disposableWithBlock:^{
			@strongify(observerDisposable, objectDisposable, deallocDisposable);
			[observerDisposable removeDisposable:deallocDisposable];
			[objectDisposable removeDisposable:deallocDisposable];
			[KVODisposable dispose];
		}];
	}] setNameWithFormat:@"RACAble(%@, %@)", object, keyPath];
}

- (RACSignal *)rac_signalForKeyPath:(NSString *)keyPath observer:(NSObject *)observer {
	return [self.class rac_signalFor:self keyPath:keyPath observer:observer];
}

- (RACDisposable *)rac_deriveProperty:(NSString *)keyPath from:(RACSignal *)signal {
	return [signal toProperty:keyPath onObject:self];
}

- (RACCompoundDisposable *)rac_deallocDisposable {
	@synchronized(self) {
		RACCompoundDisposable *compoundDisposable = objc_getAssociatedObject(self, RACObjectCompoundDisposable);
		if (compoundDisposable == nil) {
			compoundDisposable = [RACCompoundDisposable compoundDisposable];
			objc_setAssociatedObject(self, RACObjectCompoundDisposable, compoundDisposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			objc_setAssociatedObject(self, RACObjectScopedDisposable, compoundDisposable.asScopedDisposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}

		return compoundDisposable;
	}
}

- (void)rac_addDeallocDisposable:(RACDisposable *)disposable {
	[self.rac_deallocDisposable addDisposable:disposable];
}

@end
