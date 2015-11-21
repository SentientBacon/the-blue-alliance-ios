//
//  TBARankingsViewController.m
//  the-blue-alliance-ios
//
//  Created by Zach Orr on 7/3/15.
//  Copyright (c) 2015 The Blue Alliance. All rights reserved.
//

#import "TBARankingsViewController.h"
#import "TBARankingTableViewCell.h"
#import "District.h"
#import "DistrictRanking.h"
#import "Event.h"

static NSString *const RankCellReuseIdentifier  = @"RankCell";

@implementation TBARankingsViewController
@synthesize fetchedResultsController = _fetchedResultsController;

#pragma mark - Properities

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest;
    NSPredicate *predicate;
    NSString *cacheName;
    if (self.event) {
        fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"EventRanking"];
        predicate = [NSPredicate predicateWithFormat:@"event == %@", self.event];
        cacheName = [NSString stringWithFormat:@"%@_rankings", self.event.key];
    } else if (self.district) {
        fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"DistrictRanking"];
        predicate = [NSPredicate predicateWithFormat:@"district == %@", self.district];
        cacheName = [NSString stringWithFormat:@"%@_rankings", self.district.key];
    }
    [fetchRequest setPredicate:predicate];
    
    NSSortDescriptor *rankSortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:YES];
    [fetchRequest setSortDescriptors:@[rankSortDescriptor]];
    
    // Need a cache name here
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                    managedObjectContext:self.persistenceController.managedObjectContext
                                                                      sectionNameKeyPath:nil
                                                                               cacheName:cacheName];
    _fetchedResultsController.delegate = self;
    
    NSError *error = nil;
    if (![self.fetchedResultsController performFetch:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _fetchedResultsController;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tbaDelegate = self;
    self.cellIdentifier = RankCellReuseIdentifier;
    
    __weak typeof(self) weakSelf = self;
    self.refresh = ^void() {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        [strongSelf hideNoDataView];
        [strongSelf refreshRankings];
    };
}

#pragma mark - Data Methods

- (void)refreshRankings {
    [self updateRefresh:YES];

    __weak typeof(self) weakSelf = self;
    __block NSUInteger request = [[TBAKit sharedKit] fetchRankingsForDistrictShort:self.district.key forYear:[self.district.year unsignedIntegerValue] withCompletionBlock:^(NSArray *rankings, NSInteger totalCount, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        [strongSelf removeRequestIdentifier:request];
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf showErrorAlertWithMessage:@"Unable to reload district rankings"];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                // TODO: These large inserts are hanging our UI thread. We need to look in to fixing it.
                [DistrictRanking insertDistrictRankingsWithDistrictRankings:rankings forDistrict:strongSelf.district inManagedObjectContext:strongSelf.persistenceController.managedObjectContext];
                [strongSelf.persistenceController save];
            });
        }
    }];
    [self addRequestIdentifier:request];
}

#pragma mark - TBA Table View Data Source

- (void)configureCell:(TBARankingTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if (self.district) {
        DistrictRanking *ranking = [self.fetchedResultsController objectAtIndexPath:indexPath];
        cell.districtRanking = ranking;
    } else if (self.event) {
        EventRanking *ranking = [self.fetchedResultsController objectAtIndexPath:indexPath];
        cell.eventRanking = ranking;
    }
}

#pragma mark - Table View Delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.rankingSelected) {
        id ranking = [self.fetchedResultsController objectAtIndexPath:indexPath];
        self.rankingSelected(ranking);
    }
}

@end
