//
//  TBAAwardsViewController.m
//  the-blue-alliance
//
//  Created by Zach Orr on 4/3/16.
//  Copyright © 2016 The Blue Alliance. All rights reserved.
//

#import "TBAAwardsViewController.h"
#import "TBAAwardTableViewCell.h"
#import "Award.h"
#import "AwardRecipient.h"
#import "Event.h"
#import "Team.h"

@implementation TBAAwardsViewController

@synthesize fetchedResultsController = _fetchedResultsController;

#pragma mark - Properities

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }

    if (!self.persistentContainer) {
        return nil;
    }
    
    NSFetchRequest *fetchRequest = [Award fetchRequest];
    NSPredicate *predicate;
    if (self.team) {
        predicate =[NSPredicate predicateWithFormat:@"event == %@ AND (ANY recipients.team == %@)", self.event, self.team];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"event == %@", self.event];
    }
    [fetchRequest setPredicate:predicate];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"awardType" ascending:YES]]];

    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                    managedObjectContext:self.persistentContainer.viewContext
                                                                      sectionNameKeyPath:nil
                                                                               cacheName:nil];
    _fetchedResultsController.delegate = self;
    
    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _fetchedResultsController;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tbaDelegate = self;
    self.cellIdentifier = AwardCellReuseIdentifier;
    
    UINib *cellNib = [UINib nibWithNibName:NSStringFromClass([TBAAwardTableViewCell class]) bundle:nil];
    [self.tableView registerNib:cellNib forCellReuseIdentifier:self.cellIdentifier];
    
    __weak typeof(self) weakSelf = self;
    self.refresh = ^void() {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf refreshAwards];
    };
}

#pragma mark - Data Methods

- (BOOL)shouldNoDataRefresh {
    return self.fetchedResultsController.fetchedObjects.count == 0;
}

- (void)refreshAwards {
    __weak typeof(self) weakSelf = self;
    __block NSUInteger request = [[TBAKit sharedKit] fetchAwardsForEventKey:self.event.key withCompletionBlock:^(NSArray *awards, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        if (error) {
            [strongSelf showErrorAlertWithMessage:@"Unable to reload event matches"];
        }

        [strongSelf.persistentContainer performBackgroundTask:^(NSManagedObjectContext * _Nonnull backgroundContext) {
            Event *event = [backgroundContext objectWithID:strongSelf.event.objectID];
            [Award insertAwardsWithModelAwards:awards forEvent:event inManagedObjectContext:backgroundContext];
            [backgroundContext save:nil];
            [strongSelf removeRequestIdentifier:request];
        }];
    }];
    [self addRequestIdentifier:request];
}

#pragma mark - TBA Table View Data Source

- (void)configureCell:(TBAAwardTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    Award *award = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.award = award;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)showNoDataView {
    [self showNoDataViewWithText:@"No awards for this event"];
}

#pragma mark - Table View Delegate

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];    
}

@end
