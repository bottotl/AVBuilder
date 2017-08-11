//
//  JFTVideoPickerController.m
//  JFTAVEditor
//
//  Created by jft0m on 2017/8/2.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTVideoPickerController.h"
#import "JFTVideoPickerCollectionViewCell.h"
#import <Photos/Photos.h>

@interface JFTVideoPickerController ()<UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UINavigationControllerDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, assign) CGFloat cellWidth;
@property (nonatomic, strong) NSArray <PHAsset *> *photoAssets;
@end

@implementation JFTVideoPickerController

- (instancetype)init {
    if (self = [super init]) {
        CGFloat balanceValue = 100;
        NSInteger viewCount = [UIScreen mainScreen].bounds.size.width / balanceValue;
        CGFloat width = [UIScreen mainScreen].bounds.size.width -( viewCount - 1 ) * 10 - 30;
        width = width / viewCount;
        _cellWidth = width;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[UICollectionViewFlowLayout new]];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    
    [self.collectionView registerClass:[JFTVideoPickerCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
    self.collectionView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.collectionView];
    
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    self.collectionView.collectionViewLayout = layout;
    
    [self requestPermissionAndFetchData];
    
    self.title = @"视频";
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.collectionView.frame = self.view.bounds;
    
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    
    CGFloat margin = 15;
    layout.itemSize = CGSizeMake(self.cellWidth, self.cellWidth);
    layout.sectionInset = UIEdgeInsetsMake(margin, margin, margin, margin);
    layout.minimumInteritemSpacing = 10;
    layout.minimumLineSpacing = layout.minimumInteritemSpacing;
    [layout invalidateLayout];
}

- (void)requestPermissionAndFetchData {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            [self loadVideos];
        }
    }];
}

- (void)loadVideos {
    PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumVideos options:nil];
    PHAssetCollection *videoCollection = smartAlbums.firstObject;
    PHFetchOptions *options = [PHFetchOptions new];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    PHFetchResult *result = [PHAsset fetchAssetsInAssetCollection:videoCollection options:options];
    NSMutableArray <PHAsset *> *videos = [NSMutableArray new];
    [result enumerateObjectsUsingBlock:^(PHAsset * _Nonnull  obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [videos addObject:obj];
    }];
    self.photoAssets = videos.copy;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
    });
}

#pragma mark CollectionView delegate & datasource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.photoAssets.count;
}
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    JFTVideoPickerCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    PHAsset *asset = self.photoAssets[indexPath.row];
    
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
    
    [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
        if (imageData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *image = [UIImage imageWithData:imageData];
                cell.imageView.image = image;
                [cell setNeedsLayout];
                [cell layoutIfNeeded];
            });
        }
    }];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PHAsset *phAsset = self.photoAssets[indexPath.row];
    PHVideoRequestOptions *options = [PHVideoRequestOptions new];
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
    options.networkAccessAllowed = YES;
    [[PHImageManager defaultManager] requestAVAssetForVideo:phAsset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
        if (asset) {
            NSLog(@"get avasset");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.didPickAsset) {
                    self.didPickAsset(asset);
                }
            });
        }
    }];
}

@end
