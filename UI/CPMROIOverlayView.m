/**
 * CPMROIOverlayView.m
 *
 * Drag-a-rectangle selector drawn above the game. It is only "alive" while
 * -beginSelection has been called: at any other time it must not swallow a single
 * touch, otherwise the game behind it stops responding.
 */
#import "CPMROIOverlayView.h"

#import <QuartzCore/QuartzCore.h>

@interface CPMROIOverlayView ()
@property (nonatomic, assign, readwrite) CGRect selectedRect;
@property (nonatomic, assign, readwrite) BOOL isSelecting;
@property (nonatomic, strong) UIView *selectionRectView;
@property (nonatomic, strong) CAShapeLayer *guideLayer;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, assign) CGPoint startPoint;
@end

@implementation CPMROIOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isSelecting = NO;
        _selectedRect = CGRectZero;
        _showGuides = YES;
        _showCenterCrosshair = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self setupView];
    }
    return self;
}

- (instancetype)init {
    return [self initWithFrame:CGRectZero];
}

- (void)setupView {
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
    self.hidden = YES;
    self.layer.allowsEdgeAntialiasing = YES;

    self.selectionRectView = [[UIView alloc] initWithFrame:CGRectZero];
    self.selectionRectView.backgroundColor = [[UIColor systemYellowColor] colorWithAlphaComponent:0.18];
    self.selectionRectView.layer.borderColor = [UIColor systemYellowColor].CGColor;
    self.selectionRectView.layer.borderWidth = 2;
    self.selectionRectView.layer.cornerRadius = 4;
    self.selectionRectView.userInteractionEnabled = NO;
    self.selectionRectView.hidden = YES;
    [self addSubview:self.selectionRectView];

    self.guideLayer = [CAShapeLayer layer];
    self.guideLayer.fillColor = [UIColor clearColor].CGColor;
    self.guideLayer.strokeColor = [[UIColor whiteColor] colorWithAlphaComponent:0.75].CGColor;
    self.guideLayer.lineWidth = 1;
    self.guideLayer.lineDashPattern = @[@4, @4];
    [self.layer addSublayer:self.guideLayer];

    self.hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 44)];
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    self.hintLabel.numberOfLines = 2;
    self.hintLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.hintLabel.textColor = [UIColor whiteColor];
    self.hintLabel.text = @"Kutuyu aracın boya alanının üzerine sürükle";
    self.hintLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.hintLabel.userInteractionEnabled = NO;
    [self addSubview:self.hintLabel];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.selectionRectView.layer.borderColor = [UIColor systemYellowColor].CGColor;
    [self redrawGuides];
}

- (void)setHidden:(BOOL)hidden {
    [super setHidden:hidden];
    if (!hidden) [self setNeedsLayout];
}

#pragma mark selection mode

- (void)beginSelection {
    self.isSelecting = YES;
    self.hidden = NO;
    self.userInteractionEnabled = YES;
    self.startPoint = CGPointZero;
    self.selectionRectView.hidden = YES;
    self.hintLabel.text = @"Kutuyu aracın boya alanının üzerine sürükle";
    [self setNeedsLayout];
}

- (void)cancelSelection {
    self.isSelecting = NO;
    self.selectedRect = CGRectZero;
    self.selectionRectView.hidden = YES;
    self.hidden = YES;
    [self redrawGuides];
    if ([self.delegate respondsToSelector:@selector(roiOverlayDidCancel:)]) {
        [self.delegate roiOverlayDidCancel:self];
    }
}

- (void)finishSelection {
    self.isSelecting = NO;
    self.hidden = YES;
    [self redrawGuides];
    if (CGRectGetWidth(self.selectedRect) > 24 && CGRectGetHeight(self.selectedRect) > 24) {
        if ([self.delegate respondsToSelector:@selector(roiOverlay:didFinishWithRect:)]) {
            [self.delegate roiOverlay:self didFinishWithRect:self.selectedRect];
        }
    }
}

- (void)clearSelection {
    self.selectedRect = CGRectZero;
    self.selectionRectView.hidden = YES;
    [self redrawGuides];
}

/// Show an already-picked rect (the panel's "adjust region" button).
- (void)showSelectedRect:(CGRect)rect {
    self.selectedRect = rect;
    self.selectionRectView.frame = CGRectStandardize(rect);
    self.selectionRectView.hidden = CGRectIsEmpty(rect);
    [self setNeedsLayout];
}

#pragma mark - touches

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    (void)event;
    /* Only while the user is picking a region. Anything else must fall through to the
     * game, or the whole screen would go dead. */
    return self.isSelecting && CGRectContainsPoint(self.bounds, point);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.isSelecting) { [super touchesBegan:touches withEvent:event]; return; }
    UITouch *touch = touches.anyObject;
    self.startPoint = [touch locationInView:self];
    self.selectedRect = CGRectZero;
    self.selectionRectView.hidden = YES;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.isSelecting) { [super touchesMoved:touches withEvent:event]; return; }
    UITouch *touch = touches.anyObject;
    CGPoint current = [touch locationInView:self];
    CGRect rect = CGRectMake(MIN(self.startPoint.x, current.x), MIN(self.startPoint.y, current.y),
                             fabs(current.x - self.startPoint.x), fabs(current.y - self.startPoint.y));
    CGFloat minSide = 24;
    if (rect.size.width < minSide) rect.size.width = minSide;
    if (rect.size.height < minSide) rect.size.height = minSide;
    rect = CGRectIntersection(rect, self.bounds);
    if (CGRectIsNull(rect)) return;
    self.selectedRect = rect;
    self.selectionRectView.frame = rect;
    self.selectionRectView.hidden = NO;
    self.hintLabel.text = [NSString stringWithFormat:@"%.0f × %.0f pt — bırakınca onaylanır",
                           rect.size.width, rect.size.height];
    [self setNeedsLayout];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.isSelecting) { [super touchesEnded:touches withEvent:event]; return; }
    self.hintLabel.text = @"Kutuyu aracın boya alanının üzerine sürükle";
    [self finishSelection];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.isSelecting) { [super touchesCancelled:touches withEvent:event]; return; }
    [self cancelSelection];
}

#pragma mark guides

- (void)redrawGuides {
    CGRect target = CGRectIsEmpty(self.selectedRect) ? self.bounds : self.selectedRect;
    UIBezierPath *path = [UIBezierPath bezierPath];

    if (self.showGuides && !CGRectIsEmpty(self.selectedRect)) {
        for (NSInteger i = 1; i <= 2; i++) {
            CGFloat x = CGRectGetMinX(self.selectedRect) + CGRectGetWidth(self.selectedRect) * i / 3.0;
            CGFloat y = CGRectGetMinY(self.selectedRect) + CGRectGetHeight(self.selectedRect) * i / 3.0;
            [path moveToPoint:CGPointMake(x, CGRectGetMinY(self.selectedRect))];
            [path addLineToPoint:CGPointMake(x, CGRectGetMaxY(self.selectedRect))];
            [path moveToPoint:CGPointMake(CGRectGetMinX(self.selectedRect), y)];
            [path addLineToPoint:CGPointMake(CGRectGetMaxX(self.selectedRect), y)];
        }
    }
    if (self.showCenterCrosshair) {
        CGPoint center = CGPointMake(CGRectGetMidX(target), CGRectGetMidY(target));
        CGFloat len = self.isSelecting ? 26 : 14;
        [path moveToPoint:CGPointMake(center.x - len, center.y)];
        [path addLineToPoint:CGPointMake(center.x + len, center.y)];
        [path moveToPoint:CGPointMake(center.x, center.y - len)];
        [path addLineToPoint:CGPointMake(center.x, center.y + len)];
    }
    self.guideLayer.frame = self.bounds;
    self.guideLayer.path = path.CGPath;
}

- (void)setShowGuides:(BOOL)showGuides {
    _showGuides = showGuides;
    [self redrawGuides];
}

- (void)setShowCenterCrosshair:(BOOL)showCenterCrosshair {
    _showCenterCrosshair = showCenterCrosshair;
    [self redrawGuides];
}

@end
