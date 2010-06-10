
@import <AppKit/CPCollectionView.j>
@import <AppKit/CPViewAnimation.j>


@implementation CollectionView : CPCollectionView
{
    CPCollectionViewItem draggedItem;
    int                  dragIndex;
    CPViewAnimation      animation;
}

- (BOOL)wantsPeriodicDraggingUpdates
{
    return YES;
}

- (void)dragView:(CPView)aView at:(CPPoint)aLocation offset:(CPSize)mouseOffset event:(CPEvent)anEvent pasteboard:(CPPasteboard)aPasteboard source:(id)aSourceObject slideBack:(BOOL)slideBack
{
    // slideBack is forced to NO because it isn't implemented yet, but I don't breakage once it is
    [super dragView:aView at:aLocation offset:mouseOffset event:anEvent pasteboard:aPasteboard source:aSourceObject slideBack:NO];
    
    var index = [[self selectionIndexes] firstIndex];
    
    draggedItem = [self itemAtIndex:index];
    
    [[draggedItem view] setAlphaValue:0.0]; // bugs with setHidden
    [self setDragIndex:index];
}

- (BOOL)prepareForDragOperation:(id)sender
{
    return dragIndex != nil;
}

- (BOOL)performDragOperation:(id)sender
{
    var delegate = [self delegate],
        indexes = [self selectionIndexes];
    
    if (![delegate respondsToSelector:@selector(collectionView:canMoveItemsAtIndexes:toIndex:)] ||
        ![delegate collectionView:self canMoveItemsAtIndexes:indexes toIndex:dragIndex])
        return NO;
    
    [[self content] moveIndexes:indexes toIndex:dragIndex];
    [self setSelectionIndexes:[CPIndexSet indexSetWithIndex:dragIndex]];
    
    if ([delegate respondsToSelector:@selector(collectionView:didMoveItemsAtIndexes:toIndex:)])
        [delegate collectionView:self didMoveItemsAtIndexes:indexes toIndex:dragIndex];
    
    return YES;
}

- (void)draggedView:(CPImage)aView endedAt:(CGPoint)aLocation operation:(CPDragOperation)anOperation
{
    var index = [[self selectionIndexes] firstIndex], // may or may not have been changed
        contentView = [[self window] contentView],
        dragFrame = [[[CPDragServer sharedDragServer] draggedWindow] frame],
        start = [contentView convertPoint:dragFrame.origin fromView:nil],
        end = [contentView convertPoint:[[[self itemAtIndex:index] view] frameOrigin] fromView:self];
        
    [self setDragIndex:index];
    
    if (!animation)
    {
        animation = [[CPViewAnimation alloc] initWithDuration:0.2 animationCurve:CPAnimationLinear];
        [animation setDelegate:self];
    }
    
    [aView setFrameOrigin:start];
    [contentView addSubview:aView];
    
    animateViewToPoint(aView, end, animation);
}

- (void)animationDidEnd:(CPViewAnimation)aViewAnimation
{
    var dragView = [[aViewAnimation viewAnimations][0] valueForKey:CPViewAnimationTargetKey],
        view = [draggedItem view];
    
    [[[CPDragServer sharedDragServer] draggedView] removeFromSuperview];
    
    [view setHidden:NO]; // fixes bug
    [view setAlphaValue:1.0];
    
    draggedItem = nil;
    dragIndex = nil;
}

- (void)draggingExited:(id)sender
{
    [self setDragIndex:nil];
}

- (CPDragOperation)draggingUpdated:(id)sender
{
    var location = [self convertPoint:[sender draggingLocation] fromView:nil],
        row = FLOOR(location.y / (_itemSize.height + _verticalMargin)),
        column = FLOOR(location.x / (_itemSize.width + _horizontalMargin)),
        index = MIN(row * [self numberOfColumns] + column, [[self items] count] - 1);
    
    if (dragIndex != index)
        [self setDragIndex:index];
    
    return CPDragOperationMove;
}

- (void)setDragIndex:(int)index
{
    dragIndex = index;
    
    var items = [self items],
        count = [items count];
    
    [items removeObject:draggedItem];
    // the array needs to stay the same length
    [items insertObject:draggedItem atIndex:(dragIndex == nil ? count : dragIndex)];
    
    for (var i = count; i--; )
        [[items[i] view] stopAnimation];
    
    [self tile];
}

@end


@implementation CollectionViewItem : CPCollectionViewItem
{
    
}

- (void)setView:(CPView)aView
{
    var cell = [[CollectionViewCell alloc] initWithFrame:[aView frame]];
    [aView setAutoresizingMask:CPViewHeightSizable | CPViewWidthSizable];
    [cell addSubview:aView];
    
    [super setView:cell];
}

@end


@implementation CollectionViewCell : CPView
{
    CPViewAnimation animation;
}

- (void)stopAnimation
{
    [animation stopAnimation];
}

- (void)setRepresentedObject:(id)anObject
{
    var subview = [self subviews][0];
    
    if ([subview respondsToSelector:@selector(setRepresentedObject:)])
        [subview setRepresentedObject:anObject];
}

- (void)setSelected:(BOOL)flag
{
    var subview = [self subviews][0];
    
    if ([subview respondsToSelector:@selector(setSelected:)])
        [subview setSelected:flag];
}

- (void)setFrameOrigin:(CGPoint)aPoint
{
    if ([animation isAnimating] ||
        ![self superview] ||
        ![[CPDragServer sharedDragServer] isDragging] ||
        ![[self superview] isKindOfClass:[CollectionView class]])
    {
        [super setFrameOrigin:aPoint];
    }
    else if (aPoint && !CGPointEqualToPoint([self frameOrigin], aPoint))
    {
        [self animateTo:aPoint];
    }
}

- (void)animateTo:(CGPoint)aPoint
{
    if (!animation)
        animation = [[CPViewAnimation alloc] initWithDuration:0.2 animationCurve:CPAnimationLinear];
    
    animateViewToPoint(self, aPoint, animation);
}

@end


var animateViewToPoint = function(view, point, animation)
{
    var dict = [CPDictionary dictionary],
        frame1 = [view frame],
        frame2 = [view frame];
        
    frame2.origin = point;
        
    [dict setValue:view forKey:CPViewAnimationTargetKey];
    [dict setValue:frame1 forKey:CPViewAnimationStartFrameKey];
    [dict setValue:frame2 forKey:CPViewAnimationEndFrameKey];
    
    [animation setViewAnimations:[dict]];
    [animation startAnimation];
};


@implementation CPArray (MoveIndexes)

- (void)moveIndexes:(CPIndexSet)indexes toIndex:(int)insertIndex
{
    var index = [indexes lastIndex],
        aboveCount = 0,
        object;
    
    while (index != CPNotFound)
    {
        if (index >= insertIndex)
            index += aboveCount++;
        
        object = [self objectAtIndex:index];
        [self removeObjectAtIndex:index];
        [self insertObject:object atIndex:insertIndex];
        
        index = [indexes indexLessThanIndex:index];
    }
}

@end
