//
//  WindowDelegate.m
//  QuietYou
//

#import "ViewController.h"

#import <ServiceManagement/ServiceManagement.h>

#define IgnoreItemsTableViewDragType @"net.briankendall.QuietYou.ignoreitem"

@interface ViewController ()
@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSButton *enableCheckbox;
@property (strong) IBOutlet NSTableView *tableView;
@property (strong) IBOutlet NSButton *removeIgnoreItemButton;
@property (strong) NSMutableArray<NSString *> *ignoreStrings;
@end

@implementation ViewController {
    SMAppService *agentService;
    NSUserDefaults *appDefaults;
    NSTextField *placeholderLabel;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    placeholderLabel = nil;
    
    agentService = [SMAppService agentServiceWithPlistName:@"net.briankendall.QuietYou.agent.plist"];
    self.enableCheckbox.state =
        (agentService.status == SMAppServiceStatusEnabled) ? NSControlStateValueOn : NSControlStateValueOff;
    
    appDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"net.briankendall.QuietYou.shared"];
    NSArray *inIgnoreStrings = [appDefaults objectForKey:@"ignoreStrings"];
    self.ignoreStrings = [NSMutableArray arrayWithArray:inIgnoreStrings ? inIgnoreStrings : @[]];
    [self updateIgnoreStrings];
    
    self.tableView.headerView = nil;
    self.tableView.target = self;
    self.tableView.doubleAction = @selector(tableViewDoubleClick:);
    [self.tableView registerForDraggedTypes:@[IgnoreItemsTableViewDragType, NSPasteboardTypeString]];
    [self.tableView setDraggingSourceOperationMask:(NSDragOperationCopy | NSDragOperationMove) forLocal:YES];
    [self.tableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
}

- (IBAction)enableButtonClicked:(id)sender {
    if (self.enableCheckbox.state == NSControlStateValueOn) {
        [self startAgent];
    } else {
        [self stopAgent];
    }
}

- (void)startAgent {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        bool success = [self->agentService registerAndReturnError:&error];

        if (success) {
            return;
        }
        
        NSLog(@"startAgent error: %@", error.description);

        dispatch_async(dispatch_get_main_queue(), ^{
            self.enableCheckbox.state = (self->agentService.status == SMAppServiceStatusEnabled)
                                            ? NSControlStateValueOn
                                            : NSControlStateValueOff;
            [self displayError:NSLocalizedString(@"Failed to start the QuietYou background agent!", @"") error:error];
        });
    });
}

- (void)stopAgent {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        bool success = [self->agentService unregisterAndReturnError:&error];

        if (success) {
            return;
        }
        
        NSLog(@"stopAgent error: %@", error.description);

        dispatch_async(dispatch_get_main_queue(), ^{
            self.enableCheckbox.state = (self->agentService.status == SMAppServiceStatusEnabled)
                                            ? NSControlStateValueOn
                                            : NSControlStateValueOff;
            [self displayError:NSLocalizedString(@"Failed to stop the QuietYou background agent!", @"") error:error];
        });
    });
}

- (void)displayError:(NSString *)message error:(NSError *)error {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert setInformativeText:[NSString
                                  stringWithFormat:NSLocalizedString(@"Error message: %@",
                                                                     @"%@ will be replaced with an error description"),
                                                   error.localizedDescription]];
    [alert setAlertStyle:NSAlertStyleCritical];
    [alert
        addButtonWithTitle:
            NSLocalizedString(@"Aw Nuts",
                              @"This is a quote from Carl in episode 12 'Mountain of Madness' from season 8 of The "
                              @"Simpsons. Perhaps use the lines as it was translated in the show? Or not, whatever.")];
    [alert runModal];
}

- (NSTextField *)createPlaceholderLabel
{
    NSTextField *label = [[NSTextField alloc] init];
    label.stringValue = NSLocalizedString(@"Add text here", @"");
    label.font = [NSFont systemFontOfSize:13];
    label.textColor = [NSColor secondaryLabelColor];
    label.editable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    [label setFrame:NSMakeRect(4, 4, 200, 50)];
    [self.tableView addSubview:label];
    
    return label;
}

- (void)updateIgnoreStrings {
    [appDefaults setObject:[NSArray arrayWithArray:self.ignoreStrings] forKey:@"ignoreStrings"];
    
    if (self.ignoreStrings.count == 0) {
        if (!placeholderLabel) {
            placeholderLabel = [self createPlaceholderLabel];
        }
        
        [placeholderLabel setHidden:NO];
    } else if (placeholderLabel) {
        [placeholderLabel setHidden:YES];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.ignoreStrings.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = tableColumn.identifier;
    NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:nil];
    cell.textField.stringValue = (self.ignoreStrings.count > row) ? [self.ignoreStrings objectAtIndex:row] : @"";
    cell.textField.target = self;
    cell.textField.action = @selector(textFieldDidEndEditing:);
    
    return cell;
}

- (void)textFieldDidEndEditing:(id)sender {
    NSTextField *textField = (NSTextField *)sender;
    NSInteger row = [self.tableView rowForView:textField];
    
    if (row == -1) {
        return;
    }
    
    if (textField.stringValue.length == 0) {
        [self.ignoreStrings removeObjectAtIndex:row];
        [self.tableView reloadData];
        [self updateIgnoreStrings];
        return;
    }
    
    self.ignoreStrings[row] = textField.stringValue;
    [self updateIgnoreStrings];
}

- (void)tableViewDoubleClick:(id)sender {
    NSInteger row = [self.tableView clickedRow];
    
    if (row < 0) {
        return;
    }
    
    [self.tableView editColumn:0 row:row withEvent:nil select:YES];
}

- (nullable id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
    [item setString:[NSString stringWithFormat:@"%ld", (long)row] forType:IgnoreItemsTableViewDragType];
    return item;
}

- (NSDragOperation)tableView:(NSTableView *)tableView
                 validateDrop:(id<NSDraggingInfo>)info
                  proposedRow:(NSInteger)row
        proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    NSPasteboard *pasteboard = [info draggingPasteboard];
    
    if ([pasteboard stringForType:IgnoreItemsTableViewDragType]) {
        return ([NSEvent modifierFlags] & NSEventModifierFlagOption) ? NSDragOperationCopy : NSDragOperationMove;
    }
    
    return NSDragOperationCopy;
}

- (BOOL)handleInternalDrop:(NSString *)stringValue row:(NSInteger)row {
    NSInteger sourceRow = [stringValue integerValue];
    
    if (sourceRow < 0 || sourceRow >= self.ignoreStrings.count) {
        return NO;
    }
    
    NSString *draggedItem = self.ignoreStrings[sourceRow];
    NSDragOperation operation = ([NSEvent modifierFlags] & NSEventModifierFlagOption) ? NSDragOperationCopy : NSDragOperationMove;
    
    if (operation == NSDragOperationMove) {
        if (sourceRow == row || (sourceRow + 1) == row) {
            return NO;
        }
        
        [self.ignoreStrings removeObjectAtIndex:sourceRow];
        
        if (sourceRow < row) {
            row--;
        }
        
        [self.ignoreStrings insertObject:draggedItem atIndex:row];
        [self updateIgnoreStrings];
        
    } else if (operation == NSDragOperationCopy) {
        [self.ignoreStrings insertObject:[NSString stringWithString:draggedItem] atIndex:row];
        [self updateIgnoreStrings];
    }
    
    [self.tableView reloadData];

    return YES;
}

- (BOOL)tableView:(NSTableView *)tableView
       acceptDrop:(id<NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)dropOperation
{
    NSPasteboard *pasteboard = [info draggingPasteboard];
    NSString *stringValue;
    
    stringValue = [pasteboard stringForType:IgnoreItemsTableViewDragType];
    
    if (stringValue) {
        return [self handleInternalDrop:stringValue row:row];
    }
    
    stringValue = [pasteboard stringForType:NSPasteboardTypeString];
    
    if (stringValue) {
        [self.ignoreStrings insertObject:stringValue atIndex:row];
        [self.tableView reloadData];
        [self updateIgnoreStrings];
        
        return YES;
    }
    
    return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self.removeIgnoreItemButton setEnabled:(self.tableView.selectedRowIndexes.count > 0)];
}

- (IBAction)addIgnoreItem:(id)sender {
    [self.ignoreStrings addObject:@""];
    NSInteger newIndex = self.ignoreStrings.count - 1;

    NSIndexSet *newIndexSet = [NSIndexSet indexSetWithIndex:newIndex];
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexes:newIndexSet withAnimation:NSTableViewAnimationEffectNone];
    [self.tableView endUpdates];

    [self.tableView selectRowIndexes:newIndexSet byExtendingSelection:NO];
    [self.tableView scrollRowToVisible:newIndex];
    [self.tableView editColumn:0 row:newIndex withEvent:nil select:YES];
}

- (IBAction)removeIgnoreItem:(id)sender {
    NSIndexSet *selectedRows = self.tableView.selectedRowIndexes;
    
    if (selectedRows.count == 0) {
        return;
    }
    
    [self.ignoreStrings removeObjectsAtIndexes:selectedRows];
    [self.tableView reloadData];
    [self updateIgnoreStrings];
}

@end
