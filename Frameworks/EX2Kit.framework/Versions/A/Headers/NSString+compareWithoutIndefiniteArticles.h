//
//  NSString+compareWithoutIndefiniteArticles.h
//  iSub
//
//  Created by Ben Baron on 12/17/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (compareWithoutIndefiniteArticles)

- (NSString *)stringWithoutIndefiniteArticle;
- (NSComparisonResult)compareWithoutIndefiniteArticles:(NSString *)otherString;
- (NSComparisonResult)caseInsensitiveCompareWithoutIndefiniteArticles:(NSString *)otherString;

@end