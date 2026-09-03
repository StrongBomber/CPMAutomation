/**
 * CPMAutoDrawViewController.m — the automation panel.
 *
 * Layout is frame-based inside a scroll view (the panel lives in the overlay window,
 * where Auto Layout constraints against the safe area are a source of surprises).
 */
#import "CPMAutoDrawViewController.h"
#import "CPMExecutionController.h"
#import "CPMIl2CppBridge.h"
#import "CPMUICalibration.h"
#import "CPMVinylShape.h"
#import "CPMTouchInjector.h"
#import "OverlayCommon.h"

static const CGFloat kPanelPadding = 14.0;
static const CGFloat kPanelRowHeight = 40.0;

@interface CPMAutoDrawViewController () {
    CPMUICalibration *_calibration;
    CPMExecutionController *_executionController;
    BOOL _previewMode;

}
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *content;
@property (nonatomic, assign) CGFloat contentHeight;
@property (nonatomic, assign) CGFloat contentWidth;
@property (nonatomic, strong) UIButton *loadImageBtn;
@property (nonatomic, strong) UIButton *clearImageBtn;
@property (nonatomic, strong) UIButton *selectRegionBtn;
@property (nonatomic, strong) UIButton *previewBtn;
@property (nonatomic, strong) UISlider *layerLimitSlider;
@property (nonatomic, strong) UILabel *layerLimitLabel;
@property (nonatomic, strong) UISlider *touchDelaySlider;
@property (nonatomic, strong) UILabel *touchDelayLabel;
@property (nonatomic, strong) UISegmentedControl *mappingControl;
@property (nonatomic, strong) UILabel *calInfoLabel;
@property (nonatomic, strong) UISegmentedControl *calStepControl;
@property (nonatomic, assign) NSInteger calTargetIndex;
@property (nonatomic, assign) CGFloat calStep;
@property (nonatomic, strong) UISwitch *previewOnlySwitch;
@property (nonatomic, strong) UISwitch *autoSaveSwitch;
@property (nonatomic, strong) UIView *regionRow;
@property (nonatomic, strong) UIButton *startBtn;
/// Shapes from the last successful preview; BAŞLAT reuses them instead of re-running the
/// (single-flight) decomposer, so "preview then start" cannot collide or stall.
@property (nonatomic, copy, nullable) NSArray<CPMVinylShape *> *previewShapes;
@property (nonatomic, assign) CGSize previewImageSize;
@property (nonatomic, strong) UIButton *pauseBtn;
@property (nonatomic, strong) UIButton *stopBtn;
@property (nonatomic, strong) UIButton *emergencyBtn;
@property (nonatomic, strong) UIButton *doneRegionBtn;
@property (nonatomic, strong) UIButton *cancelRegionBtn;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *layerCountLabel;
@property (nonatomic, strong) UILabel *diagnosticsLabel;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIImageView *thumbnail;
@end

@implementation CPMAutoDrawViewController

- (instancetype)init {
    return [self initWithNibName:nil bundle:nil];
}

- (void)loadView {
    CGSize screen = [UIScreen mainScreen].bounds.size;
    CGFloat width = MIN(screen.width, 380.0);
    self.contentWidth = width - 2 * kPanelPadding;
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, MIN(screen.height, 620))];
    self.view.clipsToBounds = YES;
    [self buildControls];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self restorePersistedControls];
    [self adoptWindowGeometry];
    self.calStep = 4.0;
    [self refreshCalibrationRow];
    [self refreshDiagnostics];
    [self syncFromController];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width,
                                             self.contentHeight + 2 * kPanelPadding);
}

/// Frame-based row placement: the panel lives in the overlay window, where Auto Layout
/// against the safe area is more surprise than help.
- (CGFloat)placeRow:(UIView *)row height:(CGFloat)height {
    row.frame = CGRectMake(kPanelPadding, self.contentHeight + kPanelPadding, self.contentWidth, height);
    [self.content addSubview:row];
    self.contentHeight = CGRectGetMaxY(row.frame) + 8;
    return CGRectGetMaxY(row.frame);
}

- (CGFloat)placeView:(UIView *)view {
    return [self placeRow:view height:kPanelRowHeight];
}

#pragma mark controls

- (void)buildControls {
    self.view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.96];
    self.view.layer.cornerRadius = 16;

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    self.content = [[UIView alloc] initWithFrame:CGRectZero];
    [self.scrollView addSubview:self.content];
    self.contentHeight = 0;

    [self placeRow:[self labelWithText:@"Otomatik Çizim"
                                  font:[UIFont systemFontOfSize:18 weight:UIFontWeightBold]
                                   color:[UIColor whiteColor]
                                  height:26]
              height:26];

    /* image row: thumbnail + two buttons */
    UIView *imageRow = [[UIView alloc] initWithFrame:CGRectZero];
    self.thumbnail = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    self.thumbnail.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    self.thumbnail.contentMode = UIViewContentModeScaleAspectFit;
    self.thumbnail.layer.cornerRadius = 6;
    self.thumbnail.userInteractionEnabled = NO;
    [imageRow addSubview:self.thumbnail];
    CGFloat halfW = (self.contentWidth - 60 - 16) / 2.0;
    self.loadImageBtn = [self buttonWithTitle:@"Görsel yükle" action:@selector(loadImageTapped)];
    self.loadImageBtn.frame = CGRectMake(60, 0, halfW, 44);
    [imageRow addSubview:self.loadImageBtn];
    self.clearImageBtn = [self buttonWithTitle:@"Temizle" action:@selector(clearImageTapped)];
    self.clearImageBtn.frame = CGRectMake(60 + halfW + 8, 0, halfW, 44);
    [imageRow addSubview:self.clearImageBtn];
    [self placeRow:imageRow height:44];

    [self placeView:[self buttonWithTitle:@"Boya alanını seç (ROI)" action:@selector(selectRegionTapped)]];

    UIView *regionRow = [[UIView alloc] initWithFrame:CGRectZero];
    CGFloat regionW = (self.contentWidth - 8) / 2.0;
    self.doneRegionBtn = [self buttonWithTitle:@"Bölgeyi onayla" action:@selector(doneRegionTapped)];
    self.doneRegionBtn.frame = CGRectMake(0, 0, regionW, 36);
    self.doneRegionBtn.hidden = YES;
    [regionRow addSubview:self.doneRegionBtn];
    self.cancelRegionBtn = [self buttonWithTitle:@"Vazgeç" action:@selector(cancelRegionTapped)];
    self.cancelRegionBtn.frame = CGRectMake(regionW + 8, 0, regionW, 36);
    self.cancelRegionBtn.hidden = YES;
    [regionRow addSubview:self.cancelRegionBtn];
    self.regionRow = regionRow;
    [self placeRow:regionRow height:36];

    [self placeView:[self buttonWithTitle:@"Planı önizle" action:@selector(previewTapped)]];

    /* sliders */
    self.layerLimitLabel = [self labelWithText:@"Katman sınırı"
                                          font:[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular]
                                           color:[UIColor colorWithWhite:0.8 alpha:1]
                                          height:16];
    [self placeRow:self.layerLimitLabel height:16];
    self.layerLimitSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, self.contentWidth, 24)];
    self.layerLimitSlider.minimumValue = 10;
    self.layerLimitSlider.maximumValue = 300;
    self.layerLimitSlider.value = 200;
    [self.layerLimitSlider addTarget:self action:@selector(layerLimitChanged:) forControlEvents:UIControlEventValueChanged];
    [self placeRow:self.layerLimitSlider height:24];

    self.touchDelayLabel = [self labelWithText:@"Yerleşme gecikmesi"
                                          font:[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular]
                                           color:[UIColor colorWithWhite:0.8 alpha:1]
                                          height:16];
    [self placeRow:self.touchDelayLabel height:16];
    self.touchDelaySlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, self.contentWidth, 24)];
    self.touchDelaySlider.minimumValue = 0;
    self.touchDelaySlider.maximumValue = 120;
    self.touchDelaySlider.value = 15;
    [self.touchDelaySlider addTarget:self action:@selector(touchDelayChanged:) forControlEvents:UIControlEventValueChanged];
    [self placeRow:self.touchDelaySlider height:24];

    [self placeRow:[self switchRowWithLabel:@"Sadece önizleme (dokunuş yok)" target:&_previewOnlySwitch
                                     action:@selector(previewOnlyChanged:)] height:32];
    [self placeRow:[self switchRowWithLabel:@"Bitince Onay'a bas" target:&_autoSaveSwitch
                                     action:@selector(autoSaveChanged:)] height:32];

    /* Which way the reference table becomes screen points. If every tap misses in the same
     * direction the mode is wrong for this device — the user can flip it here instead of
     * rebuilding the tweak. */
    [self placeRow:[self labelWithText:@"Dokunuş eşlemesi (referans → ekran)"
                                  font:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular]
                                 color:[UIColor colorWithWhite:0.8 alpha:1]
                                height:16] height:16];
    self.mappingControl = [[UISegmentedControl alloc] initWithItems:@[@"germe", @"oranlı", @"çapalı"]];
    self.mappingControl.selectedSegmentIndex = (NSInteger)self.calibration.mappingMode;
    [self.mappingControl addTarget:self action:@selector(mappingChanged:) forControlEvents:UIControlEventValueChanged];
    [self placeRow:self.mappingControl height:28];

    /* ---- on-device anchor calibration -------------------------------------
     * The compiled-in table was measured on one phone. On another device/aspect the
     * buttons are in roughly the right place but not exactly, and no amount of mapping
     * cleverness fixes a coordinate that was never measured here. These rows let the user
     * walk each anchor onto its real widget and try it, with everything saved immediately.
     */
    [self placeRow:[self labelWithText:@"Düğme kalibrasyonu — oklarla gerçek butona kaydır"
                                  font:[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold]
                                 color:[UIColor colorWithWhite:0.85 alpha:1]
                                height:16] height:16];

    self.calInfoLabel = [self labelWithText:@"…"
                                       font:[UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular]
                                      color:[UIColor colorWithWhite:0.75 alpha:1]
                                     height:30];
    self.calInfoLabel.numberOfLines = 2;
    [self placeRow:self.calInfoLabel height:30];

    UIView *pickRow = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.contentWidth, kPanelRowHeight)];
    UIButton *prev = [self buttonWithTitle:@"◀" action:@selector(calPrevTapped)];
    prev.frame = CGRectMake(0, 0, 44, kPanelRowHeight);
    [pickRow addSubview:prev];
    UIButton *next = [self buttonWithTitle:@"▶" action:@selector(calNextTapped)];
    next.frame = CGRectMake(self.contentWidth - 44, 0, 44, kPanelRowHeight);
    [pickRow addSubview:next];
    self.calStepControl = [[UISegmentedControl alloc] initWithItems:@[@"1 px", @"4 px", @"16 px"]];
    self.calStepControl.frame = CGRectMake(52, 4, self.contentWidth - 104, kPanelRowHeight - 8);
    self.calStepControl.selectedSegmentIndex = 1;
    [self.calStepControl addTarget:self action:@selector(calStepChanged:) forControlEvents:UIControlEventValueChanged];
    [pickRow addSubview:self.calStepControl];
    [self placeView:pickRow];

    UIView *nudgeRow = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.contentWidth, kPanelRowHeight)];
    CGFloat quarter = (self.contentWidth - 18) / 4.0;
    NSArray *arrows = @[ @"←", @"↑", @"↓", @"►" ];
    for (NSUInteger i = 0; i < arrows.count; i++) {
        UIButton *b = [self buttonWithTitle:arrows[i] action:@selector(calNudgeTapped:)];
        b.tag = 700 + (NSInteger)i;
        b.frame = CGRectMake(i * (quarter + 6), 0, quarter, kPanelRowHeight);
        [nudgeRow addSubview:b];
    }
    [self placeView:nudgeRow];

    UIView *calActRow = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.contentWidth, kPanelRowHeight)];
    UIButton *testBtn = [self buttonWithTitle:@"Seçili yere dokun" action:@selector(calTestTapped)];
    testBtn.frame = CGRectMake(0, 0, (self.contentWidth - 8) * 0.62, kPanelRowHeight);
    [calActRow addSubview:testBtn];
    UIButton *resetBtn = [self buttonWithTitle:@"Tabloya dön" action:@selector(calResetTapped)];
    resetBtn.frame = CGRectMake((self.contentWidth - 8) * 0.62 + 8, 0, (self.contentWidth - 8) * 0.38, kPanelRowHeight);
    [calActRow addSubview:resetBtn];
    [self placeView:calActRow];

    /* run controls */
    UIView *runRow = [[UIView alloc] initWithFrame:CGRectZero];
    CGFloat third = (self.contentWidth - 16) / 3.0;
    self.startBtn = [self buttonWithTitle:@"BAŞLAT" action:@selector(startTapped)];
    self.startBtn.frame = CGRectMake(0, 0, third, kPanelRowHeight);
    self.startBtn.backgroundColor = [UIColor systemGreenColor];
    [runRow addSubview:self.startBtn];
    self.pauseBtn = [self buttonWithTitle:@"Duraklat" action:@selector(pauseTapped)];
    self.pauseBtn.frame = CGRectMake(third + 8, 0, third, kPanelRowHeight);
    [runRow addSubview:self.pauseBtn];
    self.stopBtn = [self buttonWithTitle:@"Durdur" action:@selector(stopTapped)];
    self.stopBtn.frame = CGRectMake(2 * (third + 8), 0, third, kPanelRowHeight);
    self.stopBtn.backgroundColor = [UIColor systemRedColor];
    [runRow addSubview:self.stopBtn];
    [self placeRow:runRow height:kPanelRowHeight];

    self.emergencyBtn = [self buttonWithTitle:@"ACİL DURDUR" action:@selector(emergencyTapped)];
    self.emergencyBtn.backgroundColor = [UIColor systemRedColor];
    [self placeView:self.emergencyBtn];

    self.progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0, 0, self.contentWidth, 8)];
    [self placeRow:self.progressView height:8];

    self.statusLabel = [self labelWithText:@"Hazır."
                                      font:[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]
                                       color:[UIColor whiteColor]
                                      height:34];
    self.statusLabel.numberOfLines = 3;
    [self placeRow:self.statusLabel height:46];

    self.layerCountLabel = [self labelWithText:@"Katman: 0 / 0"
                                           font:[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular]
                                            color:[UIColor colorWithWhite:0.75 alpha:1]
                                           height:16];
    [self placeRow:self.layerCountLabel height:16];

    self.diagnosticsLabel = [self labelWithText:@"…"
                                           font:[UIFont systemFontOfSize:11]
                                            color:[UIColor systemYellowColor]
                                           height:64];
    self.diagnosticsLabel.numberOfLines = 0;
    [self placeRow:self.diagnosticsLabel height:64];

    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, self.contentWidth, 130)];
    self.logView.editable = NO;
    self.logView.selectable = YES;
    self.logView.font = [UIFont systemFontOfSize:10];
    self.logView.textColor = [UIColor colorWithWhite:0.85 alpha:1];
    self.logView.backgroundColor = [UIColor colorWithWhite:0.03 alpha:1];
    self.logView.layer.cornerRadius = 6;
    self.logView.textContainerInset = UIEdgeInsetsMake(6, 6, 6, 6);
    [self placeRow:self.logView height:130];

    self.content.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.contentHeight + kPanelPadding);
    self.executionController = self.executionController;   /* triggers the lazy wiring */
    [self.view setNeedsLayout];
}

- (UIView *)switchRowWithLabel:(NSString *)text target:(UISwitch *__strong *)outSwitch action:(SEL)action {
    UIView *row = [[UIView alloc] initWithFrame:CGRectZero];
    UILabel *label = [self labelWithText:text
                                    font:[UIFont systemFontOfSize:13]
                                   color:[UIColor whiteColor]
                                  height:32];
    label.frame = CGRectMake(0, 0, self.contentWidth - 70, 32);
    [row addSubview:label];
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(self.contentWidth - 60, 0, 60, 32)];
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];
    *outSwitch = sw;
    return row;
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color height:(CGFloat)height {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, height)];
    l.text = text;
    l.font = font;
    l.textColor = color;
    l.numberOfLines = 1;
    return l;
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];   /* declared below via the stub-friendly path */
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1];
    b.layer.cornerRadius = 8;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

#pragma mark dependencies

- (CPMUICalibration *)calibration {
    if (!_calibration) {
        _calibration = [CPMUICalibration loadFromUserDefaults] ?: [CPMUICalibration defaultCalibration];
        if (!CGRectIsNull(self.canvasScreenRect)) _calibration.canvasRect = self.canvasScreenRect;
    }
    return _calibration;
}

- (void)setCalibration:(CPMUICalibration *)calibration {
    _calibration = calibration;
    self.executionController.calibration = calibration;
}

- (CPMExecutionController *)executionController {
    if (!_executionController) {
        _executionController = [[CPMExecutionController alloc] init];
        _executionController.delegate = self;
        _executionController.calibration = self.calibration;
        _executionController.dryRun = self.previewMode;
    }
    return _executionController;
}

- (void)setExecutionController:(CPMExecutionController *)executionController {
    _executionController = executionController;
    if (executionController) {
        executionController.delegate = self;
        if (!executionController.calibration) executionController.calibration = self.calibration;
        executionController.dryRun = self.previewMode;
    }
}

/* A dry run must not look like a real run: same button, different colour, and the reason
 * one tap away in the log. */
- (void)refreshStartButtonForMode {
    self.startBtn.backgroundColor = _previewMode ? [UIColor colorWithWhite:0.45 alpha:1]
                                                 : [UIColor systemGreenColor];
    [self.startBtn setTitle:_previewMode ? @"ÖNİZLE" : @"BAŞLAT" forState:UIControlStateNormal];
}

- (void)setPreviewMode:(BOOL)previewMode {
    _previewMode = previewMode;
    self.executionController.dryRun = previewMode;
    self.previewOnlySwitch.on = previewMode;
    [self refreshStartButtonForMode];
}

#pragma mark actions

- (void)loadImageTapped {
    if ([self.delegate respondsToSelector:@selector(autoDrawControllerDidRequestImage:)]) {
        [self.delegate autoDrawControllerDidRequestImage:self];
    } else {
        [self appendLogLine:@"no image source wired — the overlay must present the picker"];
    }
}

- (void)clearImageTapped {
    [self clearReferenceImage];
}

- (void)selectRegionTapped {
    if ([self.delegate respondsToSelector:@selector(autoDrawController:didRequestROISelection:)]) {
        /* The host (OverlayManager) owns the overlay window's hit testing, so it drives
         * the selection and calls back through -roiOverlay:didFinishWithRect:. */
        [self.delegate autoDrawController:self didRequestROISelection:YES];
        return;
    }
    CPMROIOverlayView *overlay = self.roiOverlayView;
    if (!overlay) {
        [self appendLogLine:@"no ROI overlay available; using the default canvas rect"];
        return;
    }
    overlay.delegate = self;
    [overlay beginSelection];
    self.doneRegionBtn.hidden = NO;
    self.cancelRegionBtn.hidden = NO;
    [self.view setNeedsLayout];
}

- (void)doneRegionTapped {
    [self.roiOverlayView finishSelection];
    self.doneRegionBtn.hidden = YES;
    self.cancelRegionBtn.hidden = YES;
}

- (void)cancelRegionTapped {
    [self.roiOverlayView cancelSelection];
    self.doneRegionBtn.hidden = YES;
    self.cancelRegionBtn.hidden = YES;
}

- (void)previewTapped {
    if (!self.referenceImage) { [self loadImageTapped]; return; }
    [self adoptWindowGeometry];
    CPMShapeDecomposer *decomposer = [CPMShapeDecomposer sharedDecomposer];
    NSInteger cap = self.executionController.maxLayers;
    CPMShapeDecompositionConfig *cfg = [CPMShapeDecompositionConfig configForDetailedLogoWithMaxLayers:cap];
    cfg.roiRect = self.roiRect;
    __weak CPMAutoDrawViewController *weakSelf = self;
    self.statusLabel.text = @"Önizleme için ayrıştırılıyor…";
    self.startBtn.enabled = NO;
    [decomposer decomposeImage:self.referenceImage withConfig:cfg
                    completion:^(CPMShapeDecompositionResult *result, NSError *error) {
        CPMAutoDrawViewController *s = weakSelf;
        if (!s) return;
        s.startBtn.enabled = !s.executionController.isRunning;
        if (error || !result) {
            s.statusLabel.text = [NSString stringWithFormat:@"Önizleme başarısız: %@",
                                  error.localizedDescription ?: @"bilinmeyen hata"];
            s.statusLabel.textColor = [UIColor systemOrangeColor];
            s.previewShapes = nil;
            return;
        }
        s.previewShapes = result.shapes;
        s.previewImageSize = result.workingSize;
        s.statusLabel.text = result.summaryString;
        [s appendLogLine:result.summaryString];
        for (NSString *w in result.warnings) [s appendLogLine:[@"note: " stringByAppendingString:w]];
        NSArray<NSString *> *preview = [s.executionController planPreviewForShapes:result.shapes
                                                                          imageSize:result.workingSize];
        for (NSString *line in preview) [s appendLogLine:line];
        NSUInteger budget = MIN(result.shapes.count, (NSUInteger)MAX(0, cap));
        s.layerCountLabel.text = [NSString stringWithFormat:@"Katman: 0 / %lu planlandı", (unsigned long)budget];
    }];
}

- (void)startTapped {
    if (!self.referenceImage) {
        [self appendLogLine:@"pick an image first"];
        [self loadImageTapped];
        return;
    }
    [self adoptWindowGeometry];
    self.executionController.calibration = self.calibration;
    self.executionController.referenceImage = self.referenceImage;
    self.executionController.dryRun = self.previewMode;
    CPMTouchInjector *injector = [CPMTouchInjector sharedInjector];
    if (!self.previewMode && !injector.canInjectTouches) {
        /* The controller will quietly downgrade to a dry run; say so before it happens, because
         * "it ran but nothing moved" is otherwise indistinguishable from a broken automation. */
        self.statusLabel.text = [NSString stringWithFormat:@"Uyarı: dokunuş iletilemiyor (%@) — önizleme olarak çalışacak",
                                 injector.backendDescription ?: @"bilinmeyen backend"];
        self.statusLabel.textColor = [UIColor systemOrangeColor];
        [self appendLogLine:self.statusLabel.text];
    }
    if (self.previewShapes.count > 0) {
        [self appendLogLine:[NSString stringWithFormat:@"reusing the preview plan (%lu stickers)",
                             (unsigned long)self.previewShapes.count]];
        [self.executionController startWithPlan:self.previewShapes imageSize:self.previewImageSize];
    } else {
        [self.executionController startAutomationWithImage:self.referenceImage roiRect:self.roiRect];
    }
    if (!self.executionController.isRunning) {
        /* The controller reported why through didEncounterError: — do not leave the user
         * staring at an idle button. */
        [self appendLogLine:@"start refused — the reason is shown above"];
    }
    if ([self.delegate respondsToSelector:@selector(autoDrawControllerDidRequestStart:)]) {
        [self.delegate autoDrawControllerDidRequestStart:self];
    }
}

- (void)pauseTapped {
    if (self.executionController.isPaused) [self.executionController resumeAutomation];
    else [self.executionController pauseAutomation];
    if ([self.delegate respondsToSelector:@selector(autoDrawControllerDidRequestPause:)]) {
        [self.delegate autoDrawControllerDidRequestPause:self];
    }
}

- (void)stopTapped {
    [self.executionController stopAutomation];
    if ([self.delegate respondsToSelector:@selector(autoDrawControllerDidRequestStop:)]) {
        [self.delegate autoDrawControllerDidRequestStop:self];
    }
}

- (void)emergencyTapped {
    [self.executionController emergencyStop];
    if ([self.delegate respondsToSelector:@selector(autoDrawControllerDidRequestEmergencyStop:)]) {
        [self.delegate autoDrawControllerDidRequestEmergencyStop:self];
    }
}

- (void)layerLimitChanged:(UISlider *)slider {
    self.previewShapes = nil;   /* the budget decides which shapes survive */
    NSInteger limit = (NSInteger)(slider.value + 0.5f);
    self.executionController.maxLayers = limit;
    self.layerLimitLabel.text = [NSString stringWithFormat:@"Katman sınırı: %ld%@", (long)limit,
                                 [self gameCapText]];
}

- (void)touchDelayChanged:(UISlider *)slider {
    NSTimeInterval ms = slider.value;
    self.executionController.touchDelayMs = ms;
    self.touchDelayLabel.text = [NSString stringWithFormat:@"Yerleşme gecikmesi: %0.0f ms", ms];
}

- (void)previewOnlyChanged:(UISwitch *)sender {
    self.previewMode = sender.isOn;
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kCPMDefaultsPreviewOnly];
    [self appendLogLine:sender.isOn ? @"preview only: touches will not be injected"
                                    : @"live mode: touches will be injected"];
}

- (void)mappingChanged:(UISegmentedControl *)sender {
    CPMUIMappingMode mode = (CPMUIMappingMode)sender.selectedSegmentIndex;
    self.calibration.mappingMode = mode;
    [self.calibration saveToUserDefaults];
    NSString *modeName = [sender titleForSegmentAtIndex:(NSUInteger)sender.selectedSegmentIndex] ?: @"?";
    [self appendLogLine:[NSString stringWithFormat:@"mapping → %@ (kaydedildi)", modeName]];
    /* Positions shift with the mode, so anything computed against the old one is stale. */
    self.previewShapes = nil;
    [self refreshCalibrationRow];
    [self refreshDiagnostics];
}

- (void)autoSaveChanged:(UISwitch *)sender {
    self.executionController.autoSaveVinyl = sender.isOn;
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kCPMDefaultsAutoSave];
}

#pragma mark anchor calibration

- (CPMUIElementType)calTargetType {
    NSInteger count = (NSInteger)CPMUIElementTypeCount;
    NSInteger idx = ((self.calTargetIndex % count) + count) % count;
    return (CPMUIElementType)idx;
}

- (void)calPrevTapped { self.calTargetIndex -= 1; [self refreshCalibrationRow]; }
- (void)calNextTapped { self.calTargetIndex += 1; [self refreshCalibrationRow]; }

- (void)calStepChanged:(UISegmentedControl *)sender {
    self.calStep = sender.selectedSegmentIndex == 0 ? 1.0 : (sender.selectedSegmentIndex == 2 ? 16.0 : 4.0);
    [self refreshCalibrationRow];
}

- (void)calNudgeTapped:(UIButton *)sender {
    CGPoint delta = CGPointZero;
    switch (sender.tag - 700) {
        case 0: delta = CGPointMake(-self.calStep, 0); break;
        case 1: delta = CGPointMake(0, -self.calStep); break;
        case 2: delta = CGPointMake(0, self.calStep); break;
        default: delta = CGPointMake(self.calStep, 0); break;
    }
    CPMUICalibration *cal = self.calibration;
    [cal shiftAnchorForType:[self calTargetType] by:delta];
    /* A hand-placed anchor is a verified anchor; keep it that way across launches. */
    cal.userVerified = YES;
    [cal saveToUserDefaults];
    self.previewShapes = nil;
    [self refreshCalibrationRow];
}

- (void)calTestTapped {
    if (self.previewMode) {
        [self appendLogLine:@"test dokunuşu için 'Sadece önizleme' kapalı olmalı"];
        return;
    }
    CPMUICalibration *cal = self.calibration;
    CPMUIElementAnchor *a = [cal anchorForType:[self calTargetType]];
    if (!a) return;
    CGPoint centre = CGPointMake(CGRectGetMidX(a.referenceFrame), CGRectGetMidY(a.referenceFrame));
    CGPoint onScreen = [cal screenPointForReferencePoint:centre];
    [[CPMTouchInjector sharedInjector] synthesizeTapAt:onScreen];
    [self appendLogLine:[NSString stringWithFormat:@"test: %@ → ekran (%0.0f, %0.0f)",
                         CPMUIElementTypeName(a.elementType), onScreen.x, onScreen.y]];
}

- (void)calResetTapped {
    CPMUIElementAnchor *fresh = [[CPMUICalibration defaultCalibration] anchorForType:[self calTargetType]];
    CPMUIElementType type = [self calTargetType];
    if (!fresh) { [self appendLogLine:@"tablo okunamadı"]; return; }
    CGPoint centre = fresh.center;
    CGSize size = fresh.size;
    CPMUIElementAnchor *restored = [[CPMUIElementAnchor alloc] initWithType:type center:centre size:size];
    restored.sliderMinX = fresh.sliderMinX; restored.sliderMaxX = fresh.sliderMaxX;
    restored.sliderMinY = fresh.sliderMinY; restored.sliderMaxY = fresh.sliderMaxY;
    restored.inverted = fresh.inverted;
    restored.displayName = fresh.displayName;
    [self.calibration setAnchor:restored forType:type];
    [self.calibration saveToUserDefaults];
    [self appendLogLine:@"anchor tablodayki yerine döndü"];
    [self refreshCalibrationRow];
}

- (void)refreshCalibrationRow {
    CPMUICalibration *cal = self.calibration;
    CPMUIElementType type = [self calTargetType];
    CPMUIElementAnchor *a = [cal anchorForType:type];
    if (!a) { self.calInfoLabel.text = @"anchor yok"; return; }
    CGPoint centre = [cal screenPointForReferencePoint:CGPointMake(CGRectGetMidX(a.referenceFrame),
                                                                    CGRectGetMidY(a.referenceFrame))];
    NSString *name = a.displayName.length ? a.displayName : CPMUIElementTypeName(type);
    self.calInfoLabel.text = [NSString stringWithFormat:
        @"%ld/%ld · %@\nref (%0.0f, %0.0f) → ekran (%0.0f, %0.0f) · adım %0.0f px",
        (long)type + 1, (long)CPMUIElementTypeCount, name,
        a.center.x, a.center.y, centre.x, centre.y, self.calStep ?: 4.0];
}

#pragma mark persisted controls

/*
 * The panel is opened inside the game, so re-tuning the sliders on every session is worse
 * than remembering a value the user can already see. There is no registration domain in this
 * tweak, so "never stored" is detected with objectForKey: — and for the one setting that can
 * touch the game, "never stored" means the safe answer: preview only.
 */
- (void)restorePersistedControls {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d objectForKey:kCPMDefaultsLayerLimit]) [self setLayerLimit:[d integerForKey:kCPMDefaultsLayerLimit]];
    if ([d objectForKey:kCPMDefaultsTouchDelay]) [self setTouchDelay:[d doubleForKey:kCPMDefaultsTouchDelay]];
    NSNumber *preview = [d objectForKey:kCPMDefaultsPreviewOnly];
    self.previewMode = preview ? [preview boolValue] : YES;
    self.previewOnlySwitch.on = self.previewMode;
    self.mappingControl.selectedSegmentIndex = (NSInteger)self.calibration.mappingMode;
    NSNumber *autoSave = [d objectForKey:kCPMDefaultsAutoSave];
    self.executionController.autoSaveVinyl = autoSave ? [autoSave boolValue] : NO;
    self.autoSaveSwitch.on = self.executionController.autoSaveVinyl;
}

#pragma mark image / ROI plumbing

- (void)loadReferenceImage:(UIImage *)image {
    self.referenceImage = image;
    self.thumbnail.image = image;
    self.previewShapes = nil;
    self.statusLabel.text = image ? [NSString stringWithFormat:@"Görsel %0.0f×%0.0f pt — önizle ya da başlat",
                                     image.size.width, image.size.height] : @"Hazır.";
    [self appendLogLine:image ? @"image loaded" : @"image cleared"];
}

- (void)clearReferenceImage {
    self.referenceImage = nil;
    self.previewShapes = nil;
    self.thumbnail.image = nil;
    self.roiRect = CGRectNull;
    self.layerCountLabel.text = @"Katman: 0 / 0";
    [self.statusLabel setText:@"Hazır."];
}

- (void)updateROI:(CGRect)rect {
    self.roiRect = CGRectStandardize(rect);
    self.previewShapes = nil;
    [self appendLogLine:[NSString stringWithFormat:@"image ROI set to %@ — re-run the preview",
                         NSStringFromCGRect(self.roiRect)]];
}

/// The overlay's drag selects a *screen* region: that is the canvas, not the image crop.
- (void)roiOverlay:(CPMROIOverlayView *)overlay didFinishWithRect:(CGRect)rect {
    self.canvasScreenRect = CGRectStandardize(rect);
    self.calibration.canvasRect = self.canvasScreenRect;
    [self.calibration saveToUserDefaults];
    self.doneRegionBtn.hidden = YES;
    self.cancelRegionBtn.hidden = YES;
    [self appendLogLine:[NSString stringWithFormat:@"canvas = %@ (saved)", NSStringFromCGRect(self.canvasScreenRect)]];
    [self refreshDiagnostics];
}

- (void)roiOverlayDidCancel:(CPMROIOverlayView *)overlay {
    self.doneRegionBtn.hidden = YES;
    self.cancelRegionBtn.hidden = YES;
    [self appendLogLine:@"region selection cancelled"];
}

#pragma mark window geometry

/*
 * UIScreen.mainScreen.bounds does not rotate, so a profile built at launch (or restored from
 * an earlier session) can describe portrait while the game sits in landscape — or the reverse
 * after a rotation. Everything downstream (anchor taps, slider drags, the canvas rect) is
 * computed from that profile, so the panel re-aims it at the window it is actually living in
 * before it starts or previews. Cheap and idempotent: no change, no work.
 */
- (void)adoptWindowGeometry {
    UIView *host = self.view.window ?: self.view;
    CGSize size = host.bounds.size;
    if (size.width < 1 || size.height < 1) return;
    if ([self.calibration refreshForWindowSize:size]) {
        self.roiRect = CGRectNull;
        [self appendLogLine:[NSString stringWithFormat:
            @"geometry re-derived for %.0fx%.0f pt — re-confirm the paint area",
            size.width, size.height]];
    }
}

#pragma mark header API

- (void)setLayerLimit:(NSInteger)limit {
    [[NSUserDefaults standardUserDefaults] setInteger:MAX(1, limit) forKey:kCPMDefaultsLayerLimit];
    self.executionController.maxLayers = MAX(1, limit);
    self.layerLimitSlider.value = (float)MIN(300, MAX(10, limit));
    self.layerLimitLabel.text = [NSString stringWithFormat:@"Katman sınırı: %ld%@", (long)limit, [self gameCapText]];
}

- (NSInteger)layerLimit {
    return self.executionController.maxLayers;
}

- (void)setTouchDelay:(NSTimeInterval)ms {
    [[NSUserDefaults standardUserDefaults] setDouble:ms forKey:kCPMDefaultsTouchDelay];
    self.executionController.touchDelayMs = ms;
    self.touchDelaySlider.value = (float)MIN(120, MAX(0, ms));
    self.touchDelayLabel.text = [NSString stringWithFormat:@"Yerleşme gecikmesi: %0.0f ms", ms];
}

- (NSTimeInterval)touchDelay {
    return self.executionController.touchDelayMs;
}

- (void)showControlsAnimated:(BOOL)animated {
    self.view.hidden = NO;
    self.roiOverlayView.hidden = self.roiOverlayView.isSelecting;
    [self refreshDiagnostics];
    [self syncFromController];
    if (!animated) return;
    self.view.alpha = 0;
    [UIView animateWithDuration:0.2 animations:^{
        self.view.alpha = 1;
    }];
}

- (void)hideControlsAnimated:(BOOL)animated {
    if (!animated) { self.view.hidden = YES; return; }
    [UIView animateWithDuration:0.2 animations:^{
        self.view.alpha = 0;
    } completion:^(__unused BOOL finished) {
        self.view.alpha = 1;
        self.view.hidden = YES;
    }];
}

#pragma mark controller callbacks

- (void)controller:(id)controller didUpdateProgress:(CGFloat)progress {
    self.progressView.progress = (float)progress;
    id<CPMAutoDrawViewControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(autoDrawController:didUpdateProgress:)]) {
        [delegate autoDrawController:self didUpdateProgress:progress];
    }
}

- (void)controller:(id)controller didChangeState:(CPMAutomationStep)state {
    self.statusLabel.text = [self statusText];
    self.statusLabel.textColor = state == CPMAutomationStepFailed ? [UIColor systemOrangeColor]
                                                                  : [UIColor whiteColor];
    NSString *title = state == CPMAutomationStepPaused ? @"Devam" : @"Duraklat";
    [self.pauseBtn setTitle:title forState:UIControlStateNormal];
    BOOL running = state == CPMAutomationStepPlacingLayers || state == CPMAutomationStepDecomposingImage ||
                   state == CPMAutomationStepLoadingImage || state == CPMAutomationStepPaused ||
                   state == CPMAutomationStepVerifying;
    self.startBtn.enabled = !running;
    self.pauseBtn.enabled = running;
    self.stopBtn.enabled = running;
    self.previewBtn.enabled = !running;
}

- (void)controller:(id)controller didPlaceLayer:(NSUInteger)layerIndex total:(NSUInteger)total {
    self.layerCountLabel.text = [NSString stringWithFormat:@"Katman: %lu / %lu%@",
                                 (unsigned long)(layerIndex + 1), (unsigned long)total,
                                 self.executionController.isPaused ? @"  (paused)" : @""];
    id<CPMAutoDrawViewControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(autoDrawController:didUpdateLayerCount:total:)]) {
        [delegate autoDrawController:self didUpdateLayerCount:(layerIndex + 1) total:total];
    }
    [self refreshDiagnostics];
}

- (void)controller:(id)controller didLogStep:(NSString *)line {
    [self appendLogLine:line];
}

- (void)controller:(id)controller didEncounterError:(NSError *)error {
    self.statusLabel.text = [NSString stringWithFormat:@"Başlatılamadı: %@",
                             error.localizedDescription ?: @"bilinmeyen hata"];
    self.statusLabel.textColor = [UIColor systemOrangeColor];
    [self appendLogLine:[NSString stringWithFormat:@"error: %@", error.localizedDescription ?: @"?"]];
}

- (void)controllerDidFinish:(id)controller {
    self.progressView.progress = 1.0;
    self.statusLabel.text = [self statusText];
    [self appendLogLine:@"finished"];
}

#pragma mark status

- (void)syncFromController {
    CPMExecutionController *c = self.executionController;
    self.layerLimitSlider.value = (float)c.maxLayers;
    self.layerLimitLabel.text = [NSString stringWithFormat:@"Katman sınırı: %ld%@", (long)c.maxLayers,
                                 [self gameCapText]];
    self.touchDelaySlider.value = (float)c.touchDelayMs;
    self.touchDelayLabel.text = [NSString stringWithFormat:@"Yerleşme gecikmesi: %0.0f ms", c.touchDelayMs];
    self.previewOnlySwitch.on = c.dryRun;
    self.autoSaveSwitch.on = c.autoSaveVinyl;
    self.progressView.progress = (float)c.progress;
    self.layerCountLabel.text = [NSString stringWithFormat:@"Katman: %lu / %lu",
                                 (unsigned long)c.layersPlaced, (unsigned long)c.totalLayers];
    self.statusLabel.text = [self statusText];
}

- (NSString *)gameCapText {
    NSInteger gameCap = [self.executionController gameLayerLimit];
    NSInteger used = [self.executionController gameLayerCount];
    if (gameCap <= 0) return @" (oyun sınırı bilinmiyor)";
    if (used >= 0) return [NSString stringWithFormat:@" (oyun: %ld / %ld kullanımda)", (long)used, (long)gameCap];
    return [NSString stringWithFormat:@" (oyun sınırı %ld)", (long)gameCap];
}

- (void)refreshDiagnostics {
    NSMutableString *text = [NSMutableString string];
    CPMIl2CppBridge *bridge = self.executionController.bridge ?: [CPMIl2CppBridge sharedBridge];
    if (bridge.isAvailable) {
        CPMEditorReadout *readout = [bridge refresh];
        [text appendString:readout.summaryString ?: @"readout unavailable"];
        if (readout.layoutDriftCount > 0) {
            [text appendFormat:@"\n%ld offset(s) corrected live", (long)readout.layoutDriftCount];
        }
    } else {
        [text appendFormat:@"il2cpp readout off: %@", bridge.unavailableReason ?: @"unknown"];
    }
    CPMTouchInjector *injector = [CPMTouchInjector sharedInjector];
    [text appendFormat:@"\nTouch: %@%@", injector.backendDescription,
     injector.canInjectTouches ? @"" : @" — nothing will reach the game"];
    [text appendFormat:@"\nCalibration: %@", [self.calibration.validationReport
                                               stringByReplacingOccurrencesOfString:@"\n" withString:@"\n   "]];
    self.diagnosticsLabel.text = text;
    if (self.diagnosticsLabel.text.length > 0) self.diagnosticsLabel.hidden = NO;
}

- (NSString *)statusText {
    return [self.executionController statusDescription] ?: @"boşta";
}

- (void)appendLogLine:(NSString *)line {
    if (!line.length) return;
    NSString *stamp = [NSString stringWithFormat:@"%@\n", line];
    self.logView.text = [self.logView.text ?: @"" stringByAppendingString:stamp];
    NSRange end = NSMakeRange(self.logView.text.length, 0);
    [self.logView scrollRangeToVisible:end];
    [self.view setNeedsLayout];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@>", NSStringFromClass(self.class), [self statusText]];
}

@end
