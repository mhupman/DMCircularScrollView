//
//  DMCircularScrollView.m
//  DMCircularScrollView
//
//  Created by Daniele Margutti on 8/16/12.
//  Copyright (c) 2012 Daniele Margutti. All rights reserved.
//

#import "DMCircularScrollView.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - DMCircularScrollView

@interface DMCircularScrollView() <UIScrollViewDelegate>

@property (nonatomic, weak) UIScrollView* scrollView;

// Block Handlers
@property (nonatomic, copy) DMCircularScrollViewDataSource dataSource;

@property (nonatomic) NSUInteger previousPageIndex;
@property (nonatomic) NSUInteger totalPages;

@property (nonatomic) NSMutableArray* tempRepresentations;    // temp cached representation of your UIViews (if needed)
@property (nonatomic) UITapGestureRecognizer* singleTapGesture;

@property (nonatomic, readonly)  NSUInteger visiblePageCount;
@property (nonatomic, readonly)  CGSize pageSize;

// Used to disable vertical scrolling
@property (nonatomic) CGFloat previousContentOffsetY;

- (NSMutableArray *) viewsFromIndex:(NSUInteger) centralIndex preloadOffset:(NSUInteger) offsetLeftRight;
- (NSMutableArray *) circularPageIndexesFrom:(NSInteger) currentIndex byAddingOffset:(NSInteger) offset;
- (void) relayoutPageItems:(NSUInteger) forceSetPage;

@end

@implementation DMCircularScrollView

#pragma  mark - Initialization Routines

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.tempRepresentations = [[NSMutableArray alloc] init];
        self.previousPageIndex = 0;
        
        self.clipsToBounds = YES;
        
        UIScrollView* scrollView;
        
        scrollView = [[UIScrollView alloc] initWithFrame:frame];
        scrollView.pagingEnabled = YES;
        scrollView.clipsToBounds = NO;
        scrollView.showsHorizontalScrollIndicator = NO;
        scrollView.directionalLockEnabled = YES;
        scrollView.delegate = self;
        
        if (self.displayBorder)
        {
            scrollView.layer.borderColor = [UIColor greenColor].CGColor;
            scrollView.layer.borderWidth = 2;
        }
        
        scrollView.backgroundColor = [UIColor blueColor];
        self.backgroundColor = [UIColor cyanColor];
        
        self.pageWidth = 50;
        self.currentPageIndex = 0;
        self.allowTapToChangePage = YES;
        
        [self addSubview:scrollView];
        
        self.scrollView = scrollView;
    }
    
    return self;
}

- (UIView *) viewAtLocation:(CGPoint) touchLocation {
    for (UIView *subView in self.scrollView.subviews)
        if (CGRectContainsPoint(subView.frame, touchLocation))
            return subView;
    return nil;
}


- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    UIView* child = nil;
    // Allows subviews of the scrollview receiving touches
    if ((child = [super hitTest:point withEvent:event]) == self)
        return self.scrollView;
    return child;
}

#pragma mark - Properties

- (void) setAllowTapToChangePage:(BOOL)allowTapToChangePage {
    _allowTapToChangePage = allowTapToChangePage;
    
    [self.scrollView removeGestureRecognizer:self.singleTapGesture];
    if (self.singleTapGesture == nil) {
        self.singleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapGestureCaptured:)];
        self.singleTapGesture.cancelsTouchesInView = NO;
    }
    if (self.allowTapToChangePage)
    {
        [self.scrollView addGestureRecognizer:self.singleTapGesture];
    }
}

- (CGSize) pageSize {
    return CGSizeMake(self.pageWidth,self.frame.size.height);
}

- (void) setPageWidth:(CGFloat)pageWidth {
    if (pageWidth != self.pageWidth) {
        _pageWidth = pageWidth;
        [self reloadData];
    }
}

- (void) setPageCount:(NSUInteger)pageCount withDataSource:(DMCircularScrollViewDataSource)dataSource {
    self.totalPages = pageCount;
    self.dataSource = dataSource;
    [self reloadData];
}

- (void) setCurrentPageIndex:(NSUInteger)currentPageIndex {
    if (currentPageIndex != self.currentPageIndex && currentPageIndex < self.totalPages)
        [self relayoutPageItems:currentPageIndex];
}

- (NSUInteger) currentPageIndex {
    CGPoint middlePoint = CGPointMake(self.scrollView.contentOffset.x+self.pageSize.width/2,
                                      self.scrollView.contentOffset.y+self.pageSize.height/2);
    UIView *currentPageView = [self viewAtLocation:middlePoint];
    return currentPageView.tag;
}

- (NSUInteger) visiblePageCount {
    return ((self.frame.size.width/self.pageSize.width)-1);
}

#pragma mark - Handle Tap To Change Page

- (void)singleTapGestureCaptured:(UITapGestureRecognizer *)gesture {
    UIView *pickedView = [self viewAtLocation:[gesture locationInView:self.scrollView]];
    [self.scrollView setContentOffset:CGPointMake(pickedView.frame.origin.x, 0) animated:YES];
}

#pragma mark - Delegate Helper Methods

- (void) delegateSelector:(SEL)selector toDelegateWithArgument:(id)arg
{
    if (self.scrollViewDelegate && [self.scrollViewDelegate respondsToSelector:selector])
    {
        // Disable the 'leaky performSelector' warning from arc
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.scrollViewDelegate performSelector:selector withObject:arg];
#pragma clang diagnostic pop
    }
}

- (void) delegateSelector:(SEL)selector toDelegateWithArgument:(id)arg andArgument:(id)arg2
{
    if (self.scrollViewDelegate && [self.scrollViewDelegate respondsToSelector:selector])
    {
        // Disable the 'leaky performSelector' warning from arc
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.scrollViewDelegate performSelector:selector withObject:arg withObject:arg2];
#pragma clang diagnostic pop
    }
}

#pragma mark - UIScrollViewDelegate Methods

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)sv {
    [self relayoutPageItems:NSUIntegerMax];
    [self delegateSelector:@selector(scrollViewDidEndScrollingAnimation:) toDelegateWithArgument:sv];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)sv
{
    [self relayoutPageItems:NSUIntegerMax];
    [self delegateSelector:@selector(scrollViewDidEndDecelerating:) toDelegateWithArgument:sv];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)sv willDecelerate:(BOOL)decelerate
{
    if (self.scrollViewDelegate && [self.scrollViewDelegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)])
    {
        [self.scrollViewDelegate scrollViewDidEndDragging:sv willDecelerate:decelerate];
    }
}

- (void)scrollViewDidEndZooming:(UIScrollView *)sv withView:(UIView *)view atScale:(float)scale
{
    if (self.scrollViewDelegate && [self.scrollViewDelegate respondsToSelector:@selector(scrollViewDidEndZooming:withView:atScale:)])
    {
        [self.scrollViewDelegate scrollViewDidEndZooming:sv withView:view atScale:scale];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)sv
{
    // Disable vertical scrolling
    [sv setContentOffset: CGPointMake(sv.contentOffset.x, self.previousContentOffsetY)];
    
    [self delegateSelector:@selector(scrollViewDidScroll:) toDelegateWithArgument:sv];
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)sv
{
    [self delegateSelector:@selector(scrollViewDidScrollToTop:) toDelegateWithArgument:sv];
}

- (void)scrollViewDidZoom:(UIScrollView *)sv
{
    [self delegateSelector:@selector(scrollViewDidZoom:) toDelegateWithArgument:sv];
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)sv
{
    if (self.scrollViewDelegate && [self.scrollViewDelegate respondsToSelector:@selector(scrollViewShouldScrollToTop:)])
    {
        return [self.scrollViewDelegate scrollViewShouldScrollToTop:sv];
    }
    return YES;
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)sv
{
    [self delegateSelector:@selector(scrollViewWillBeginDecelerating:) toDelegateWithArgument:sv];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)sv
{
    [self delegateSelector:@selector(scrollViewWillBeginDragging:) toDelegateWithArgument:sv];
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)sv withView:(UIView *)view
{
    [self delegateSelector:@selector(scrollViewWillBeginZooming:withView:) toDelegateWithArgument:sv andArgument:view];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)sv withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (self.scrollViewDelegate && [self.scrollViewDelegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)])
    {
        [self.scrollViewDelegate scrollViewWillEndDragging:sv withVelocity:velocity targetContentOffset:targetContentOffset];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)sv
{
    if (self.scrollViewDelegate && [self.scrollViewDelegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)])
    {
        return [self.scrollViewDelegate viewForZoomingInScrollView:sv];
    }
    return nil;
}

#pragma mark - Layout Managment

- (void) layoutSubviews
{
    [super layoutSubviews];
    
    self.scrollView.frame = CGRectMake(((self.frame.size.width-self.pageSize.width)/2.0f),
                                  self.frame.origin.y,
                                  self.pageSize.width,
                                  self.frame.size.height);
    
    self.scrollView.contentOffset = CGPointZero;
    
    [self relayoutPageItems:self.currentPageIndex];
}

- (void) reloadData {
    NSUInteger visiblePages = ceilf(self.frame.size.width/self.pageSize.width);

    // We need to check to see if self.frame.size.width is evenly divisible
    // by the pageSize width. If true then we want one more visible
    // page. 
    if (fmodf(self.frame.size.width, self.pageSize.width) == 0)
    {
        visiblePages += 1;
    }

    [self.scrollView setContentSize:CGSizeMake(self.pageSize.width*visiblePages, self.scrollView.frame.size.height)];
    
    if (self.dataSource != nil) {
        [self.scrollView setContentOffset:CGPointMake(self.pageSize.width, 0)];
        [self relayoutPageItems:NSUIntegerMax];
    }
}

#pragma mark - Internal Use

- (NSMutableArray *) circularPageIndexesFrom:(NSInteger) currentIndex byAddingOffset:(NSInteger) offset {
    NSMutableArray *indexValues = [[NSMutableArray alloc] init];
    NSInteger remainingOffset = abs(offset);
    NSInteger value = currentIndex;
    NSInteger singleStepOffset =(offset < 0 ? -1 : 1);
    
    while (remainingOffset > 0) {
        for (NSUInteger k = 0; k < abs(offset); ++k) {
            if ((value + singleStepOffset) < 0)                 value = (self.totalPages-1);
            else if ((value + singleStepOffset) >= self.totalPages)  value = 0;
            else                                                value += singleStepOffset;
            
            remainingOffset -= 1;
            
            if (offset < 0) [indexValues insertObject:[NSNumber numberWithInt:value] atIndex:0];
            else            [indexValues addObject:[NSNumber numberWithInt:value]];
        }
    }
    return indexValues;
}

- (NSMutableArray *) viewsFromIndex:(NSUInteger) centralIndex preloadOffset:(NSUInteger) offsetLeftRight {
    NSMutableArray *viewsList = [[NSMutableArray alloc] initWithCapacity:(offsetLeftRight*2)+1];
    NSMutableArray *indexesList = [self circularPageIndexesFrom:centralIndex byAddingOffset:-offsetLeftRight];
    [indexesList addObject:[NSNumber numberWithInt:centralIndex]];
    [indexesList addObjectsFromArray:[self circularPageIndexesFrom:centralIndex byAddingOffset:offsetLeftRight]];
    
    [indexesList enumerateObjectsUsingBlock:^(NSNumber* viewIndex, NSUInteger idx, BOOL *stop) {
        NSUInteger indexOfView = [viewIndex intValue];
        
        UIView *targetView = self.dataSource(indexOfView);
        targetView.tag = indexOfView;
        if (([viewsList containsObject:targetView] == NO && indexOfView != centralIndex) ||
            (centralIndex == indexOfView && idx == offsetLeftRight))
            [viewsList addObject:targetView];
        else {
            UIImageView *tempDuplicateRepr = [[UIImageView alloc] initWithImage:[self imageWithView:targetView]];
            [self.tempRepresentations addObject:tempDuplicateRepr];
            tempDuplicateRepr.tag = indexOfView;
            [viewsList addObject:tempDuplicateRepr];
        }
    }];
    
    /*
     ###    Debug purpose only
     */
    /*  NSMutableString *buff = [[NSMutableString alloc] init];
     [viewsList enumerateObjectsUsingBlock:^(UIView* obj, NSUInteger idx, BOOL *stop) {
     [buff appendFormat:@"%d%@,",obj.tag,([obj isKindOfClass:[UIImageView class]] ? @"*":@"")];
     }];
     NSLog(@"%@",buff);
     */
    return viewsList;
}

- (void) relayoutPageItems:(NSUInteger) forceSetPage {
    NSUInteger pageToSet = (forceSetPage != NSUIntegerMax ? forceSetPage : self.currentPageIndex);
    
    self.currentPageIndex = pageToSet;
    
    [self.tempRepresentations makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.tempRepresentations removeAllObjects];
    
    if (self.handlePageChange != nil)
        self.handlePageChange(self.currentPageIndex,self.previousPageIndex);
    
    NSUInteger visiblePagesPerSide = ceilf(floor(self.frame.size.width/self.pageSize.width)/2.0f);
    NSUInteger pagesToCachePerSide = visiblePagesPerSide*2;
    
    NSArray *viewsToLoad = [self viewsFromIndex:pageToSet preloadOffset:pagesToCachePerSide];
    
    [self.scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    CGFloat offset_x = -((self.pageSize.width*pagesToCachePerSide)-self.pageSize.width);
    
    for (UIView *targetView in viewsToLoad) {
        targetView.frame = CGRectMake(offset_x, 0, self.pageSize.width, self.pageSize.height);
        [self.scrollView addSubview:targetView];
        offset_x+=self.pageSize.width;
    }
    [self.scrollView setContentOffset:CGPointMake(self.pageSize.width, 0)];
    
    self.previousPageIndex = self.currentPageIndex;
}

- (UIImage *) imageWithView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}


@end