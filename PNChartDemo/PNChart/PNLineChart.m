//
//  PNLineChart.m
//  PNChartDemo
//
//  Created by kevin on 11/7/13.
//  Copyright (c) 2013年 kevinzhow. All rights reserved.
//

#import "PNLineChart.h"
#import "PNColor.h"
#import "PNChartLabel.h"
#import "PNLineChartData.h"
#import "PNLineChartDataItem.h"
#import "UIBezierPath+Smoothing.h"

#define kYLabelWidth (20.f)
#define kXLabelHeight (20.f)
#define kyLabelTag (1)

//------------------------------------------------------------------------------------------------
// private interface declaration
//------------------------------------------------------------------------------------------------
@interface PNLineChart ()

@property (nonatomic,strong) NSMutableArray *chartLineArray; // Array[CAShapeLayer]

@property (strong, nonatomic) NSMutableArray *chartPath; //Array of line path, one for each line.

- (void)setDefaultValues;

@end


//------------------------------------------------------------------------------------------------
// public interface implementation
//------------------------------------------------------------------------------------------------
@implementation PNLineChart

#pragma mark initialization

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setDefaultValues];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setDefaultValues];
    }
    return self;
}

#pragma mark instance methods

-(void)setYLabels:(NSArray *)yLabels {
    for (UIView* subview in self.subviews) {
        if (subview.tag == kyLabelTag) {
            [subview removeFromSuperview];
        }
    }
    
    float level = _yValueMax / 5.0;
    
    NSInteger index = 0;
	NSInteger num = [yLabels count] + 1;
	while (num > 0) {
		CGFloat levelHeight = _chartCavanHeight /5.0;
		PNChartLabel * label = [[PNChartLabel alloc] initWithFrame:CGRectMake(0.0,
                                                                              _chartCavanHeight - index * levelHeight + (levelHeight/2 - yLabelHeight/2),
                                                                              kYLabelWidth,
                                                                              yLabelHeight)];
		[label setTextAlignment:NSTextAlignmentRight];
		label.text = [NSString stringWithFormat:@"%1.f",level * index];
		[self addSubview:label];
        label.tag = kyLabelTag;
        index +=1 ;
		num -= 1;
	}
}

-(void)setXLabels:(NSArray *)xLabels
{
    _xLabels = xLabels;
    
    if(_showLabel){
        _xLabelWidth = (self.frame.size.width - chartMargin - 30.0)/[xLabels count];
        
        for(int index = 0; index < xLabels.count; index++)
        {
            NSString* labelText = xLabels[index];
            PNChartLabel * label = [[PNChartLabel alloc] initWithFrame:CGRectMake(index * _xLabelWidth + 30.0, self.frame.size.height - 30.0, _xLabelWidth, kXLabelHeight)];
            [label setTextAlignment:NSTextAlignmentCenter];
            label.text = labelText;
            [self addSubview:label];
        }
        
    }else{
        _xLabelWidth = (self.frame.size.width)/[xLabels count];
    }
    
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.delegate) {
        [self touchPoint:touches withEvent:event];
    } else {
        [super touchesBegan:touches withEvent:event];
    }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.delegate) {
        [self touchPoint:touches withEvent:event];
    } else {
        [super touchesMoved:touches withEvent:event];
    }
}

-(void)touchPoint:(NSSet *)touches withEvent:(UIEvent *)event
{
    //Get the point user touched
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self];
    for (UIBezierPath *path in _chartPath) {
        CGPathRef originalPath = path.CGPath;
        CGPathRef strokedPath = CGPathCreateCopyByStrokingPath(originalPath, NULL, 3.0, kCGLineCapRound, kCGLineJoinRound, 3.0);
        BOOL pathContainsPoint = CGPathContainsPoint(strokedPath, NULL, touchPoint, NO);
        if (pathContainsPoint)
        {
            [_delegate userClickedOnLinePoint:touchPoint lineIndex:[_chartPath indexOfObject:path]];
            for (NSArray *linePointsArray in _pathPoints) {
                for (NSValue *val in linePointsArray) {
                    CGPoint p = [val CGPointValue];
                    if (p.x + 3.0 > touchPoint.x && p.x - 3.0 < touchPoint.x && p.y + 3.0 > touchPoint.y && p.y - 3.0 < touchPoint.y ) {
                        //Call the delegate and pass the point and index of the point
                        [_delegate userClickedOnLineKeyPoint:touchPoint lineIndex:[_pathPoints indexOfObject:linePointsArray] andPointIndex:[linePointsArray indexOfObject:val]];
                    }
                }
            }
            
        }
    }
    
}

-(void)strokeChartAnimated:(BOOL)animated
{
    _chartPath = [NSMutableArray array];
    [_pathPoints removeAllObjects];
    
    CGFloat xPosition = self.showLabel ? (kYLabelWidth + 10) : 0;
    
    // Draw each line
    for (NSUInteger lineIndex = 0; lineIndex < self.chartData.count; lineIndex++) {
        PNLineChartData *chartData = self.chartData[lineIndex];
        CAShapeLayer *chartLine = (CAShapeLayer *) self.chartLineArray[lineIndex];

        UIGraphicsBeginImageContext(self.frame.size);
        UIBezierPath * bezierPath = [UIBezierPath bezierPath];
        [_chartPath addObject:bezierPath];
        
        PNLineChartDataItem *firstDataItem = chartData.getData(0);
        CGFloat firstValue = firstDataItem.y;

        if(!_showLabel){
            _chartCavanHeight = self.frame.size.height  - _xLabelHeight*2;
        }

        CGFloat grade = (float)firstValue / _yValueMax;
        NSMutableArray * linePointsArray = [[NSMutableArray alloc] init];
        [bezierPath moveToPoint:CGPointMake( xPosition, _chartCavanHeight - grade * _chartCavanHeight + _xLabelHeight)];
        [linePointsArray addObject:[NSValue valueWithCGPoint:CGPointMake( xPosition, _chartCavanHeight - grade * _chartCavanHeight + _xLabelHeight)]];

        CGFloat w = self.frame.size.width - (_showLabel ? yLabelMargin : 0);
        CGFloat xStep = (w - xPosition) / (chartData.itemCount - 1);
        NSInteger index = 0;
        for (NSUInteger i = 0; i < chartData.itemCount; i++) {

            PNLineChartDataItem *dataItem = chartData.getData(i);
            float value = dataItem.y;

            CGFloat innerGrade = value / _yValueMax;
            if (index != 0) {
                CGPoint point = CGPointMake(xPosition + (index * xStep), _chartCavanHeight - (innerGrade * _chartCavanHeight) + _xLabelHeight);
                [linePointsArray addObject:[NSValue valueWithCGPoint:point]];
                [bezierPath addLineToPoint:point];
                [bezierPath moveToPoint:point];
            }
            index += 1;
        }
        [_pathPoints addObject:[linePointsArray copy]];
        // setup the color of the chart line
        if (chartData.color) {
            chartLine.strokeColor = [chartData.color CGColor];
        }else{
            chartLine.strokeColor = [PNGreen CGColor];
        }

        chartLine.path = bezierPath.CGPath;
        if (animated) {
            CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            pathAnimation.duration = 1.5f;
            pathAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            pathAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
            pathAnimation.toValue = [NSNumber numberWithFloat:1.0f];
            [chartLine addAnimation:pathAnimation forKey:@"strokeEndAnimation"];
        }
        chartLine.strokeEnd = 1.0;

        UIGraphicsEndImageContext();
    }
}

- (void)setChartData:(NSArray *)data {
    if (data != _chartData) {

        NSMutableArray *yLabelsArray = [NSMutableArray arrayWithCapacity:data.count];
        CGFloat yMax = 0.0f;

        // remove all shape layers before adding new ones
        for (CALayer *layer in self.chartLineArray) {
            [layer removeFromSuperlayer];
        }
        self.chartLineArray = [NSMutableArray arrayWithCapacity:data.count];

        for (PNLineChartData *chartData in data) {

            // create as many chart line layers as there are data-lines
            CAShapeLayer *chartLine = [CAShapeLayer layer];
            chartLine.lineCap   = kCALineCapRound;
            chartLine.lineJoin  = kCALineJoinRound;
            chartLine.fillColor = [[UIColor whiteColor] CGColor];
            chartLine.lineWidth = 3.0;
            chartLine.strokeEnd = 0.0;
            [self.layer addSublayer:chartLine];
            [self.chartLineArray addObject:chartLine];

            for (NSUInteger i = 0; i < chartData.itemCount; i++) {
                PNLineChartDataItem *dataItem = chartData.getData(i);
                CGFloat yValue = dataItem.y;
                [yLabelsArray addObject:[NSString stringWithFormat:@"%2f", yValue]];
                yMax = fmaxf(yMax, dataItem.y);
            }
        }

        // Min value for Y label
        if (yMax < 5) {
            yMax = 5.0f;
        }
        _yValueMax = yMax;

        _chartData = data;

        if (_showLabel) {
            [self setYLabels:yLabelsArray];
        }

        [self setNeedsDisplay];
    }
}

#pragma mark private methods

- (void)setDefaultValues {
    // Initialization code
    self.backgroundColor = [UIColor whiteColor];
    self.clipsToBounds   = YES;
    self.chartLineArray  = [NSMutableArray array];
    _showLabel           = YES;
    _pathPoints = [NSMutableArray array];
    self.userInteractionEnabled = YES;
    _xLabelHeight = kXLabelHeight;
    _chartCavanHeight = self.frame.size.height - chartMargin * 2 - _xLabelHeight*2 ;
}

@end
