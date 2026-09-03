/**
 * CPMVinylShape.m — plain data + a few geometric helpers. No UIKit drawing, no state.
 */
#import "CPMVinylShape.h"
#import "OverlayCommon.h"

#import <math.h>

NSString *CPMShapeTypeName(CPMShapeType type) {
    switch (type) {
        case CPMShapeTypeSquare: return @"square";
        case CPMShapeTypeCircle: return @"circle";
        case CPMShapeTypeTriangle: return @"triangle";
        case CPMShapeTypeLine: return @"line";
        case CPMShapeTypePolygon: return @"polygon";
        case CPMShapeTypeText: return @"text";
    }
    return @"unknown";
}

@implementation CPMVinylShape

- (instancetype)initWithType:(CPMShapeType)type
                    position:(CGPoint)pos
                       scale:(CGSize)size
                    rotation:(CGFloat)rotationDegrees
                       color:(UIColor *)color
                        opacity:(CGFloat)opacity {
    self = [super init];
    if (self) {
        _shapeType = type;
        _position = pos;
        _scale = CGSizeMake(fabs(size.width), fabs(size.height));
        _rotationDegrees = CPMNormalizeAngle(rotationDegrees);
        _redComponent = 1; _greenComponent = 1; _blueComponent = 1;
        _alphaComponent = CPMClamp(opacity, 0, 1);
        _identifier = [NSString stringWithFormat:@"%@-%@", CPMShapeTypeName(type),
                       [[NSUUID UUID] UUIDString]];
        [self applyUIColor:color];
    }
    return self;
}

- (instancetype)init {
    return [self initWithType:CPMShapeTypeSquare
                     position:CGPointZero
                        scale:CGSizeMake(1, 1)
                     rotation:0
                        color:[UIColor whiteColor]
                       opacity:1];
}

- (void)applyUIColor:(UIColor *)color {
    if (!color) return;
    CGFloat r = 1, g = 1, b = 1, a = 1;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        _redComponent = CPMClamp(r, 0, 1);
        _greenComponent = CPMClamp(g, 0, 1);
        _blueComponent = CPMClamp(b, 0, 1);
        _alphaComponent = CPMClamp(a, 0, 1);
    }
}

#pragma mark derived

- (UIColor *)color {
    return [UIColor colorWithRed:_redComponent green:_greenComponent blue:_blueComponent alpha:_alphaComponent];
}

- (CGFloat)opacity { return _alphaComponent; }

- (uint32_t)packedColorRGBA {
    return CPMPackRGBA((uint8_t)(_redComponent * 255.0 + 0.5),
                       (uint8_t)(_greenComponent * 255.0 + 0.5),
                       (uint8_t)(_blueComponent * 255.0 + 0.5),
                       (uint8_t)(_alphaComponent * 255.0 + 0.5));
}

- (CGRect)bounds {
    CGRect base = CGRectMake(_position.x - _scale.width * 0.5,
                             _position.y - _scale.height * 0.5,
                             _scale.width, _scale.height);
    if (fabs(_rotationDegrees) < 0.001) return base;
    CGFloat rad = _rotationDegrees * M_PI / 180.0;
    CGFloat pts[4][2] = {
        {CGRectGetMinX(base), CGRectGetMinY(base)},
        {CGRectGetMaxX(base), CGRectGetMinY(base)},
        {CGRectGetMaxX(base), CGRectGetMaxY(base)},
        {CGRectGetMinX(base), CGRectGetMaxY(base)},
    };
    CGFloat minX = CGFLOAT_MAX, minY = CGFLOAT_MAX, maxX = -CGFLOAT_MAX, maxY = -CGFLOAT_MAX;
    CGFloat cosr = cos(rad), sinr = sin(rad);
    for (int i = 0; i < 4; i++) {
        CGFloat dx = pts[i][0] - _position.x;
        CGFloat dy = pts[i][1] - _position.y;
        CGFloat x = _position.x + dx * cosr - dy * sinr;
        CGFloat y = _position.y + dx * sinr + dy * cosr;
        minX = MIN(minX, x); maxX = MAX(maxX, x);
        minY = MIN(minY, y); maxY = MAX(maxY, y);
    }
    return CGRectMake(minX, minY, maxX - minX, maxY - minY);
}

- (NSArray<NSValue *> *)generatedOutline {
    switch (_shapeType) {
        case CPMShapeTypeCircle: {
            NSMutableArray<NSValue *> *out = [NSMutableArray arrayWithCapacity:24];
            for (int i = 0; i < 24; i++) {
                CGFloat a = (CGFloat)i / 24.0 * 2.0 * (CGFloat)M_PI;
                [out addObject:[NSValue valueWithCGPoint:CGPointMake(cos(a) * 0.5, sin(a) * 0.5)]];
            }
            return out;
        }
        case CPMShapeTypeTriangle:
            return @[[NSValue valueWithCGPoint:CGPointMake(0, -0.5)],
                     [NSValue valueWithCGPoint:CGPointMake(0.5, 0.5)],
                     [NSValue valueWithCGPoint:CGPointMake(-0.5, 0.5)]];
        case CPMShapeTypeText:
        case CPMShapeTypeSquare:
        case CPMShapeTypeLine:
        case CPMShapeTypePolygon:
        default:
            return @[[NSValue valueWithCGPoint:CGPointMake(-0.5, -0.5)],
                     [NSValue valueWithCGPoint:CGPointMake(0.5, -0.5)],
                     [NSValue valueWithCGPoint:CGPointMake(0.5, 0.5)],
                     [NSValue valueWithCGPoint:CGPointMake(-0.5, 0.5)]];
    }
}

- (NSArray<NSValue *> *)outlineInImagePoints {
    NSArray<NSValue *> *local = _polygonVertices.count >= 3 ? _polygonVertices : [self generatedOutline];
    CGFloat rad = _rotationDegrees * M_PI / 180.0;
    CGFloat cosr = cos(rad), sinr = sin(rad);
    NSMutableArray<NSValue *> *out = [NSMutableArray arrayWithCapacity:local.count];
    for (NSValue *v in local) {
        CGPoint p = v.CGPointValue;
        if (_flipX) p.x = -p.x;
        CGFloat x = p.x * _scale.width;
        CGFloat y = p.y * _scale.height;
        CGPoint rotated = CGPointMake(_position.x + x * cosr - y * sinr,
                                      _position.y + x * sinr + y * cosr);
        [out addObject:[NSValue valueWithCGPoint:rotated]];
    }
    return out;
}

- (BOOL)isInsideRect:(CGRect)rect {
    return CGRectContainsRect(rect, self.bounds);
}

#pragma mark transforms

- (instancetype)shapeByOffsettingBy:(CGPoint)delta andScalingBy:(CGFloat)factor {
    CPMVinylShape *copy = [self copy];
    copy.position = CGPointMake(_position.x + delta.x * factor, _position.y + delta.y * factor);
    copy.scale = CGSizeMake(_scale.width * factor, _scale.height * factor);
    // The local frame is resolution independent, so the vertices need no rescale.
    copy.polygonVertices = _polygonVertices;
    copy.areaPixels = _areaPixels * factor * factor;
    return copy;
}

- (instancetype)shapeWithOrder:(NSInteger)order {
    CPMVinylShape *copy = [self copy];
    copy.zOrder = order;
    return copy;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    CPMVinylShape *c = [[CPMVinylShape alloc] initWithType:_shapeType
                                                   position:_position
                                                      scale:_scale
                                                   rotation:_rotationDegrees
                                                      color:self.color
                                                     opacity:_alphaComponent];
    c.identifier = _identifier;
    c.yAngle = _yAngle;
    c.xAngle = _xAngle;
    c.zDepth = _zDepth;
    c.zOrder = _zOrder;
    c.flipX = _flipX;
    c.polygonVertices = _polygonVertices;
    c.text = _text;
    c.fontIndex = _fontIndex;
    c.bold = _bold;
    c.italic = _italic;
    c.areaPixels = _areaPixels;
    return c;
}

#pragma mark serialization

- (NSDictionary<NSString *, id> *)toCPMParametersDictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"id"] = _identifier ?: @"";
    d[@"type"] = CPMShapeTypeName(_shapeType);
    d[@"x"] = @(_position.x);
    d[@"y"] = @(_position.y);
    d[@"w"] = @(_scale.width);
    d[@"h"] = @(_scale.height);
    d[@"rot"] = @(_rotationDegrees);
    d[@"yAngle"] = @(_yAngle);
    d[@"xAngle"] = @(_xAngle);
    d[@"z"] = @(_zDepth);
    d[@"order"] = @(_zOrder);
    d[@"flipX"] = @(_flipX);
    d[@"r"] = @(_redComponent);
    d[@"g"] = @(_greenComponent);
    d[@"b"] = @(_blueComponent);
    d[@"a"] = @(_alphaComponent);
    d[@"area"] = @(_areaPixels);
    if (_polygonVertices.count) {
        NSMutableArray *pts = [NSMutableArray arrayWithCapacity:_polygonVertices.count];
        for (NSValue *v in _polygonVertices) {
            CGPoint p = v.CGPointValue;
            [pts addObject:@[@(p.x), @(p.y)]];
        }
        d[@"verts"] = pts;
    }
    if (_shapeType == CPMShapeTypeText && _text.length) {
        d[@"text"] = _text;
        d[@"fontIndex"] = @(_fontIndex);
        d[@"bold"] = @(_bold);
        d[@"italic"] = @(_italic);
    }
    return d;
}

+ (instancetype)shapeWithDictionary:(NSDictionary<NSString *, id> *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    CPMVinylShape *s = [[CPMVinylShape alloc] init];
    NSString *type = dict[@"type"];
    if ([type isKindOfClass:NSString.class]) {
        if ([type isEqualToString:@"circle"]) s.shapeType = CPMShapeTypeCircle;
        else if ([type isEqualToString:@"triangle"]) s.shapeType = CPMShapeTypeTriangle;
        else if ([type isEqualToString:@"line"]) s.shapeType = CPMShapeTypeLine;
        else if ([type isEqualToString:@"polygon"]) s.shapeType = CPMShapeTypePolygon;
        else if ([type isEqualToString:@"text"]) s.shapeType = CPMShapeTypeText;
        else s.shapeType = CPMShapeTypeSquare;
    }
    if (s.shapeType != CPMShapeTypeSquare) s.polygonVertices = nil;   // outlines are polygons only
    NSNumber *n;
    CGFloat x = [dict[@"x"] doubleValue], y = [dict[@"y"] doubleValue];
    s.position = CGPointMake(x, y);
    n = dict[@"w"]; CGFloat w = n ? n.doubleValue : 1;
    n = dict[@"h"]; CGFloat h = n ? n.doubleValue : 1;
    s.scale = CGSizeMake(w, h);
    n = dict[@"rot"]; if (n) s.rotationDegrees = CPMNormalizeAngle(n.doubleValue);
    n = dict[@"yAngle"]; if (n) s.yAngle = n.doubleValue;
    n = dict[@"xAngle"]; if (n) s.xAngle = n.doubleValue;
    n = dict[@"z"]; if (n) s.zDepth = n.doubleValue;
    n = dict[@"order"]; if (n) s.zOrder = n.integerValue;
    n = dict[@"flipX"]; if (n) s.flipX = n.boolValue;
    n = dict[@"r"]; if (n) s.redComponent = CPMClamp(n.doubleValue, 0, 1);
    n = dict[@"g"]; if (n) s.greenComponent = CPMClamp(n.doubleValue, 0, 1);
    n = dict[@"b"]; if (n) s.blueComponent = CPMClamp(n.doubleValue, 0, 1);
    n = dict[@"a"]; if (n) s.alphaComponent = CPMClamp(n.doubleValue, 0, 1);
    n = dict[@"area"]; if (n) s.areaPixels = n.doubleValue;
    id idVal = dict[@"id"];
    if ([idVal isKindOfClass:NSString.class] && [idVal length]) s.identifier = idVal;
    NSArray *verts = dict[@"verts"];
    if ([verts isKindOfClass:NSArray.class] && verts.count >= 3) {
        NSMutableArray<NSValue *> *vs = [NSMutableArray arrayWithCapacity:verts.count];
        for (id pair in verts) {
            if (![pair isKindOfClass:NSArray.class] || [(NSArray *)pair count] < 2) continue;
            CGPoint p = CGPointMake([pair[0] doubleValue], [pair[1] doubleValue]);
            [vs addObject:[NSValue valueWithCGPoint:p]];
        }
        if (vs.count >= 3) s.polygonVertices = vs;
    }
    NSString *t = dict[@"text"];
    if ([t isKindOfClass:NSString.class]) s.text = t;
    n = dict[@"fontIndex"]; if (n) s.fontIndex = n.integerValue;
    n = dict[@"bold"]; if (n) s.bold = n.boolValue;
    n = dict[@"italic"]; if (n) s.italic = n.boolValue;
    return s;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@ %@ @(%0.1f,%0.1f) %0.1fx%0.1f rot %0.1f rgb(%0.2f,%0.2f,%0.2f) a %0.2f #%ld>",
            NSStringFromClass(self.class), CPMShapeTypeName(_shapeType),
            _position.x, _position.y, _scale.width, _scale.height, _rotationDegrees,
            _redComponent, _greenComponent, _blueComponent, _alphaComponent, (long)_zOrder];
}

- (NSString *)description { return [self debugDescription]; }

#pragma mark convenience factories

+ (instancetype)squareAtPosition:(CGPoint)pos side:(CGFloat)side
                        rotation:(CGFloat)rotationDegrees color:(UIColor *)color {
    return [[self alloc] initWithType:CPMShapeTypeSquare
                             position:pos
                                scale:CGSizeMake(side, side)
                             rotation:rotationDegrees
                                color:color
                               opacity:1];
}

+ (instancetype)circleAtPosition:(CGPoint)pos diameter:(CGFloat)diameter
                           color:(UIColor *)color {
    return [[self alloc] initWithType:CPMShapeTypeCircle
                             position:pos
                                scale:CGSizeMake(diameter, diameter)
                             rotation:0
                                color:color
                               opacity:1];
}

+ (instancetype)lineFrom:(CGPoint)startPoint to:(CGPoint)endPoint
                   width:(CGFloat)width color:(UIColor *)color {
    CGFloat dx = endPoint.x - startPoint.x, dy = endPoint.y - startPoint.y;
    CGFloat len = hypotf(dx, dy);
    CGFloat angle = atan2f(dy, dx) * 180.0f / (float)M_PI;
    return [[self alloc] initWithType:CPMShapeTypeLine
                             position:CGPointMake((startPoint.x + endPoint.x) * 0.5,
                                                   (startPoint.y + endPoint.y) * 0.5)
                                scale:CGSizeMake(len, MAX(1.0, width))
                             rotation:angle
                                color:color
                               opacity:1];
}

@end
