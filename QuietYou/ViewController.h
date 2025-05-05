//
//  WindowDelegate.h
//  QuietYou
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
- (IBAction) enableButtonClicked:(id)sender;
- (IBAction) addIgnoreItem:(id)sender;
- (IBAction) removeIgnoreItem:(id)sender;
@end
