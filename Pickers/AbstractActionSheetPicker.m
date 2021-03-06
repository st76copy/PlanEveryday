//
//Copyright (c) 2011, Tim Cinel
//All rights reserved.
//
//Redistribution and use in source and binary forms, with or without
//modification, are permitted provided that the following conditions are met:
//* Redistributions of source code must retain the above copyright
//notice, this list of conditions and the following disclaimer.
//* Redistributions in binary form must reproduce the above copyright
//notice, this list of conditions and the following disclaimer in the
//documentation and/or other materials provided with the distribution.
//* Neither the name of the <organization> nor the
//names of its contributors may be used to endorse or promote products
//derived from this software without specific prior written permission.
//
//THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
//DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "AbstractActionSheetPicker.h"
#import <objc/message.h>

@interface AbstractActionSheetPicker()

@property (nonatomic, retain) UIBarButtonItem *barButtonItem;
@property (nonatomic, retain) UIView *containerView;
@property (nonatomic, assign) id target;
@property (nonatomic, assign) SEL successAction;
@property (nonatomic, assign) SEL cancelAction;
@property (nonatomic, retain) UIActionSheet *actionSheet;

@property (nonatomic, retain) NSObject *selfReference;

- (void)presentPickerForView:(UIView *)aView;

- (void)configureAndPresentActionSheetForView:(UIView *)aView;

- (void)presentActionSheet:(UIActionSheet *)actionSheet;

- (void)dismissPicker;
- (BOOL)isViewPortrait;
- (BOOL)isValidOrigin:(id)origin;
- (id)storedOrigin;
- (UIBarButtonItem *)createToolbarLabelWithTitle:(NSString *)aTitle;
- (UIToolbar *)createPickerToolbarWithTitle:(NSString *)aTitle;
- (UIBarButtonItem *)createButtonWithType:(UIBarButtonSystemItem)type target:(id)target action:(SEL)buttonAction;

- (IBAction)actionPickerDone:(id)sender;
- (IBAction)actionPickerCancel:(id)sender;
@end

@implementation AbstractActionSheetPicker


#pragma mark - Abstract Implementation

- (id)initWithTarget:(id)target successAction:(SEL)successAction cancelAction:(SEL)cancelActionOrNil origin:(id)origin  {
    self = [super init];
    if (self) {
        self.target = target;
        self.successAction = successAction;
        self.cancelAction = cancelActionOrNil;
        self.presentFromRect = CGRectZero;
        
        if ([origin isKindOfClass:[UIBarButtonItem class]])
            self.barButtonItem = origin;
        else if ([origin isKindOfClass:[UIView class]])
            self.containerView = origin;
        else
            NSAssert(NO, @"Invalid origin provided to ActionSheetPicker ( %@ )", origin);
        
        //allows us to use this without needing to store a reference in calling class
        self.selfReference = self;
    }
    return self;
}




#pragma mark - Actions

- (void)showActionSheetPicker {
    
    UIView *masterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.viewSize.width, 260)];
    
    UIToolbar *pickerToolbar = [self createPickerToolbarWithTitle:self.title];
    [pickerToolbar setBarStyle:UIBarStyleBlackTranslucent];
    //add tool bar first
    [masterView addSubview:pickerToolbar];
    
    self.pickerView = [self configuredPickerView];
    //then add picker
    [masterView addSubview:self.pickerView];
    
    //animation------
    [self presentPickerForView:masterView];
    
    
    
}

- (IBAction)actionPickerDone:(id)sender {
    [self notifyTarget:self.target didSucceedWithAction:self.successAction origin:[self storedOrigin]];
    [self dismissPicker];
}

- (IBAction)actionPickerCancel:(id)sender {
    [self notifyTarget:self.target didCancelWithAction:self.cancelAction origin:[self storedOrigin]];
    [self dismissPicker];
}


- (void)dismissPicker {
#if __IPHONE_4_1 <= __IPHONE_OS_VERSION_MAX_ALLOWED
    if (self.actionSheet)
#else
    if (self.actionSheet && [self.actionSheet isVisible])
#endif
        [self.actionSheet dismissWithClickedButtonIndex:0 animated:YES];
   
    self.actionSheet = nil;
    self.selfReference = nil;
}

#pragma mark - Custom Buttons

- (void)addCustomButtonWithTitle:(NSString *)title value:(id)value {
    if (!self.customButtons)
        self.customButtons = [[NSMutableArray alloc] init];
    if (!title)
        title = @"";
    if (!value)
        value = [NSNumber numberWithInt:0];
    NSDictionary *buttonDetails = [[NSDictionary alloc] initWithObjectsAndKeys:title, @"buttonTitle", value, @"buttonValue", nil];
    [self.customButtons addObject:buttonDetails];
}

- (IBAction)customButtonPressed:(id)sender {
    UIBarButtonItem *button = (UIBarButtonItem*)sender;
    NSInteger index = button.tag;

    
    NSDictionary *buttonDetails = [self.customButtons objectAtIndex:index];

    
    NSInteger buttonValue = [[buttonDetails objectForKey:@"buttonValue"] intValue];
    UIPickerView *picker = (UIPickerView *)self.pickerView;

    
    [picker selectRow:buttonValue inComponent:0 animated:YES];
    
    if ([self respondsToSelector:@selector(pickerView:didSelectRow:inComponent:)]) {
        
        void (*objc_msgSendTyped)(id self, SEL _cmd, id pickerView, NSInteger row, NSInteger component) = (void*)objc_msgSend; // sending Integers as params
        objc_msgSendTyped(self, @selector(pickerView:didSelectRow:inComponent:), picker, buttonValue, 0);
    }
}

- (UIToolbar *)createPickerToolbarWithTitle:(NSString *)title  {
    
    CGRect frame = CGRectMake(0, 0, self.viewSize.width, 44);
    UIToolbar *pickerToolbar = [[UIToolbar alloc] initWithFrame:frame];
    
    pickerToolbar.barStyle = UIBarStyleBlackOpaque;
    
    NSMutableArray *barItems = [[NSMutableArray alloc] init];
    NSInteger index = 0;
    
    for (NSDictionary *buttonDetails in self.customButtons) {
        NSString *buttonTitle = [buttonDetails objectForKey:@"buttonTitle"];
      //NSInteger buttonValue = [[buttonDetails objectForKey:@"buttonValue"] intValue];
        UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithTitle:buttonTitle style:UIBarButtonItemStyleBordered target:self action:@selector(customButtonPressed:)];
        button.tag = index;
        [barItems addObject:button];
        index++;
    }
    //hide cancel btn
    if (NO == self.hideCancel) {
        UIBarButtonItem *cancelBtn = [self createButtonWithType:UIBarButtonSystemItemCancel target:self action:@selector(actionPickerCancel:)];
        [barItems addObject:cancelBtn];
    }
    
    UIBarButtonItem *flexSpace = [self createButtonWithType:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    [barItems addObject:flexSpace];
    
    
    if (title){
        UIBarButtonItem *labelButton = [self createToolbarLabelWithTitle:title];
        [barItems addObject:labelButton];    
        [barItems addObject:flexSpace];
    }
    
    //done btn
    UIBarButtonItem *doneButton = [self createButtonWithType:UIBarButtonSystemItemDone target:self action:@selector(actionPickerDone:)];
    [barItems addObject:doneButton];
    [pickerToolbar setItems:barItems animated:YES];
    return pickerToolbar;
}



//create btn codes

- (UIBarButtonItem *)createToolbarLabelWithTitle:(NSString *)aTitle {
    UILabel *toolBarItemlabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 120,30)];
   // [toolBarItemlabel setTextAlignment:UITextAlignmentCenter];
    [toolBarItemlabel setTextColor:[UIColor whiteColor]];    
    [toolBarItemlabel setFont:[UIFont boldSystemFontOfSize:16]];    
    [toolBarItemlabel setBackgroundColor:[UIColor clearColor]];    
    toolBarItemlabel.text = aTitle;    
    UIBarButtonItem *buttonLabel = [[UIBarButtonItem alloc]initWithCustomView:toolBarItemlabel] ;  
    return buttonLabel;
}

- (UIBarButtonItem *)createButtonWithType:(UIBarButtonSystemItem)type target:(id)target action:(SEL)buttonAction {
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:type target:target action:buttonAction];
}

#pragma mark - Utilities and Accessors

- (CGSize)viewSize {
    if (![self isViewPortrait])
        return CGSizeMake(480, 320);
    return CGSizeMake(320, 480);
}

- (BOOL)isViewPortrait {
    return UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation);
}

- (BOOL)isValidOrigin:(id)origin {
    if (!origin)
        return NO;
    BOOL isButton = [origin isKindOfClass:[UIBarButtonItem class]];
    BOOL isView = [origin isKindOfClass:[UIView class]];
    return (isButton || isView);
}

- (id)storedOrigin {
    if (self.barButtonItem)
        return self.barButtonItem;
    return self.containerView;
}

#pragma mark - Popovers and ActionSheets

- (void)presentPickerForView:(UIView *)aView {
    
    self.presentFromRect = aView.frame;
    //for iphone
    [self configureAndPresentActionSheetForView:aView];
}

- (void)configureAndPresentActionSheetForView:(UIView *)aView {
    
    NSString *paddedSheetTitle = nil;
    CGFloat sheetHeight = self.viewSize.height - 47;
    if ([self isViewPortrait]) {
        paddedSheetTitle = @"\n\n\n"; // looks hacky to me
    } else {
        NSString *reqSysVer = @"5.0";
        NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
        if ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending) {
            sheetHeight = self.viewSize.width;
        } else {
            sheetHeight += 103;
        }
    }
    
    //----------------------------------------------------------black translucent
    self.actionSheet = [[UIActionSheet alloc] initWithTitle:paddedSheetTitle delegate:nil cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
 
    [self.actionSheet setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
    [self.actionSheet addSubview:aView];
    [self presentActionSheet:self.actionSheet];
    self.actionSheet.bounds = CGRectMake(0, 0, self.viewSize.width, sheetHeight);
    
    
    
    
}

- (void)presentActionSheet:(UIActionSheet *)actionSheet {
    

    
    if (self.barButtonItem)
        [actionSheet showFromBarButtonItem:self.barButtonItem animated:YES];
    else if (self.containerView && NO == CGRectIsEmpty(self.presentFromRect))
        [actionSheet showFromRect:self.presentFromRect inView:self.containerView animated:YES];
    else
        [actionSheet showInView:self.containerView];
}



@end

