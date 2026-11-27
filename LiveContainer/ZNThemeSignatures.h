// Original vector motifs. No external game textures, network or per-frame bitmap allocations.
// Included in StrataGuestControls.m after artwork geometry helpers.
#pragma once
static NSDictionary<NSString *,NSArray *> *ZNThemeSignatureShapes(void) {
    static NSDictionary *shapes; static dispatch_once_t once;
    dispatch_once(&once,^{ shapes=@{
    @"mushroom": @[@[@"P",@"e94748",@"8 53 10 39 19 24 33 14 50 10 67 14 81 24 90 39 92 53 81 64 19 64"],@[@"R",@"fff1c8",@"27 50 46 39 12"],@[@"E",@"fff8e8",@"33 18 34 30"],@[@"E",@"fff8e8",@"12 35 19 16"],@[@"E",@"fff8e8",@"69 35 19 16"],@[@"E",@"382e32",@"39 66 6 12"],@[@"E",@"382e32",@"55 66 6 12"]],
    @"star": @[@[@"P",@"ffd45d",@"50 7 63 35 94 39 71 61 77 92 50 77 23 92 29 61 6 39 37 35"],@[@"E",@"574135",@"40 45 6 13"],@[@"E",@"574135",@"54 45 6 13"]],
    @"flower": @[@[@"E",@"f6f4e4",@"16 9 68 65"],@[@"E",@"ed7042",@"26 19 48 45"],@[@"E",@"ffd879",@"36 28 28 27"],@[@"L",@"75be66",@"50 72 50 93"],@[@"P",@"75be66",@"49 84 18 69 23 86 49 94 77 86 82 69"]],
    @"triforce": @[@[@"P",@"f6cf64",@"50 7 72 44 28 44"],@[@"P",@"f6cf64",@"26 49 48 87 4 87"],@[@"P",@"f6cf64",@"74 49 96 87 52 87"]],
    @"sword": @[@[@"P",@"d8e8f2",@"50 4 63 25 56 65 44 65 37 25"],@[@"L",@"ffffff",@"50 17 50 58"],@[@"R",@"dbb665",@"22 61 56 10 4"],@[@"R",@"537bba",@"45 70 10 19 3"],@[@"E",@"dbb665",@"43 84 14 12"]],
    @"shield": @[@[@"P",@"476cb5",@"12 16 50 6 88 16 84 56 70 76 50 93 30 76 16 56"],@[@"P",@"c7d5dc",@"50 16 62 39 38 39"],@[@"P",@"eac968",@"31 45 47 72 15 72"],@[@"P",@"eac968",@"69 45 85 72 53 72"],@[@"L",@"f1eff0",@"12 16 50 6 88 16 84 56 70 76 50 93 30 76 16 56 12 16"]],
    @"heart": @[@[@"P",@"f17b90",@"50 88 12 49 8 33 15 20 29 15 42 20 50 32 58 20 71 15 85 20 92 33 88 49"],@[@"L",@"ffcad0",@"20 35 25 26 34 24"]],
    @"rupee": @[@[@"P",@"64e4aa",@"50 5 76 28 76 72 50 95 24 72 24 28"],@[@"P",@"c0f8c7",@"50 5 50 95 24 72 24 28"],@[@"L",@"2d8367",@"50 5 50 95"]],
    @"ocarina": @[@[@"P",@"638bdb",@"12 52 22 31 43 22 66 28 88 44 93 58 86 72 63 78 34 72 15 64"],@[@"R",@"9cbaf0",@"66 37 28 13 4"],@[@"E",@"263859",@"30 43 8 8"],@[@"E",@"263859",@"43 51 8 8"],@[@"E",@"263859",@"57 43 8 8"]],
    @"mask": @[@[@"P",@"8155b1",@"50 19 20 7 27 25 7 29 19 45 10 61 26 64 35 87 50 96 65 87 74 64 90 61 81 45 93 29 73 25 80 7"],@[@"E",@"ffca6b",@"23 32 24 31"],@[@"E",@"ffca6b",@"53 32 24 31"],@[@"E",@"ed646b",@"30 39 10 17"],@[@"E",@"ed646b",@"60 39 10 17"],@[@"L",@"e7ab66",@"38 75 50 83 62 75"]],
    @"harp": @[@[@"L",@"efc36f",@"20 87 20 15 39 7 81 31 81 57 65 83 20 87"],@[@"L",@"f7dfaa",@"34 20 34 82"],@[@"L",@"f7dfaa",@"47 26 47 80"],@[@"L",@"f7dfaa",@"60 31 60 76"],@[@"L",@"f7dfaa",@"73 37 73 64"]],
    @"hourglass": @[@[@"R",@"ecc17a",@"16 6 68 10 3"],@[@"R",@"ecc17a",@"16 84 68 10 3"],@[@"L",@"dcebf1",@"23 17 28 35 50 50 72 35 77 17"],@[@"L",@"dcebf1",@"23 83 28 65 50 50 72 65 77 83"],@[@"P",@"eac568",@"32 77 50 59 68 77"]],
    @"rod": @[@[@"L",@"a77b52",@"50 90 50 30"],@[@"E",@"f1cd70",@"31 8 38 34"],@[@"P",@"72b5dc",@"50 4 57 17 73 18 61 28 65 43 50 35 35 43 39 28 27 18 43 17"]],
    @"leaf": @[@[@"P",@"66bd73",@"10 77 17 45 32 22 63 13 91 10 88 39 77 65 56 83 29 86"],@[@"L",@"c8e59a",@"12 92 70 30"],@[@"L",@"c8e59a",@"36 68 33 38"],@[@"L",@"c8e59a",@"54 48 77 53"]],
    @"sun": @[@[@"E",@"ffd363",@"25 25 50 50"],@[@"L",@"ffd363",@"50 5 50 18"],@[@"L",@"ffd363",@"50 82 50 95"],@[@"L",@"ffd363",@"5 50 18 50"],@[@"L",@"ffd363",@"82 50 95 50"],@[@"L",@"ffd363",@"18 18 29 29"],@[@"L",@"ffd363",@"71 71 82 82"],@[@"L",@"ffd363",@"18 82 29 71"],@[@"L",@"ffd363",@"71 29 82 18"]],
    @"moon": @[@[@"P",@"b9c9fa",@"70 8 49 12 31 26 23 47 26 65 39 79 59 84 81 72 67 92 43 96 22 84 8 62 7 38 22 17 45 6"],@[@"E",@"fff0bd",@"74 15 8 8"]],
    @"sail": @[@[@"L",@"f4d69b",@"50 9 50 76"],@[@"P",@"f5e8ce",@"46 14 17 62 46 62"],@[@"P",@"e87e63",@"55 25 82 62 55 62"],@[@"P",@"ae7548",@"7 70 93 70 76 87 25 87"],@[@"L",@"75cfe2",@"5 95 25 90 45 95 65 90 95 95"]],
    @"wave": @[@[@"L",@"81d9de",@"6 36 20 25 34 36 48 47 62 36 76 25 94 36"],@[@"L",@"9be7ee",@"6 54 20 43 34 54 48 65 62 54 76 43 94 54"],@[@"L",@"6fa9ce",@"6 72 20 61 34 72 48 83 62 72 76 61 94 72"]],
    @"hat": @[@[@"P",@"69bd64",@"10 79 23 65 42 15 57 7 91 22 61 30 67 65 90 79"],@[@"R",@"e4c071",@"16 68 68 10 4"]],
    @"wolf": @[@[@"P",@"c4cdd6",@"12 9 36 25 50 20 64 25 88 9 82 47 72 68 50 92 28 68 18 47"],@[@"P",@"526277",@"23 25 39 40 61 40 77 25 70 64 50 81 30 64"],@[@"L",@"d9b66b",@"27 48 40 53"],@[@"L",@"d9b66b",@"60 53 73 48"],@[@"E",@"17242d",@"43 64 14 10"]],
    @"train": @[@[@"R",@"db7654",@"15 36 70 40 5"],@[@"R",@"edc77e",@"52 17 26 48 4"],@[@"R",@"b9dce5",@"57 23 16 18 2"],@[@"R",@"83929c",@"21 18 12 24 3"],@[@"R",@"c6b18a",@"15 13 24 8 3"],@[@"E",@"393b4d",@"16 66 24 24"],@[@"E",@"393b4d",@"59 66 24 24"]],
    @"bird": @[@[@"P",@"e98769",@"50 75 29 62 8 22 35 37 50 46 65 37 92 22 71 62"],@[@"P",@"f4d58b",@"50 46 42 28 50 13 58 28"],@[@"L",@"f5c9a0",@"20 37 35 53"],@[@"L",@"f5c9a0",@"80 37 65 53"]],
    @"painting": @[@[@"R",@"e3bc73",@"9 9 82 82 6"],@[@"R",@"534f8b",@"18 18 64 64 2"],@[@"P",@"a2d8c1",@"22 72 40 36 52 55 65 30 78 72"],@[@"E",@"efd074",@"26 24 12 12"]],
    @"crown": @[@[@"P",@"f6cd6e",@"12 23 30 46 50 10 70 46 88 23 79 77 21 77"],@[@"R",@"f6cd6e",@"20 80 60 10 3"],@[@"E",@"ed92b5",@"44 49 12 12"]],
    @"eye": @[@[@"P",@"7ed1de",@"6 51 25 30 50 21 75 30 94 51 75 72 50 81 25 72"],@[@"E",@"23445b",@"34 35 32 32"],@[@"E",@"c0f5fa",@"43 39 8 8"],@[@"L",@"7ed1de",@"50 7 50 18"],@[@"L",@"7ed1de",@"30 9 36 21"],@[@"L",@"7ed1de",@"70 9 64 21"]],
    @"tablet": @[@[@"R",@"7e9cac",@"18 7 64 86 12"],@[@"R",@"243b54",@"25 15 50 70 7"],@[@"P",@"7cdbef",@"29 50 50 32 71 50 50 68"],@[@"E",@"263f5f",@"45 45 10 10"],@[@"L",@"c3eef4",@"50 21 50 28"]],
    @"spiral": @[@[@"L",@"a0e4bb",@"78 25 62 13 39 13 20 29 13 52 23 76 44 87 68 81 83 64 80 43 65 30 46 31 35 43 38 58 51 66 62 60 63 49 54 44"]],
    @"echo": @[@[@"P",@"e8cf82",@"49 4 69 36 94 50 69 64 49 96 29 64 5 50 29 36"],@[@"P",@"a996e6",@"49 25 62 43 78 50 62 57 49 75 36 57 20 50 36 43"],@[@"E",@"fff0b4",@"45 46 8 8"]],
    @"wand": @[@[@"L",@"d8ad66",@"25 88 65 35"],@[@"P",@"f8dfa0",@"67 6 74 25 95 29 79 43 82 63 65 53 47 61 50 42 35 28 56 25"]],
    @"egg": @[@[@"P",@"f0ddd1",@"50 7 67 15 82 37 88 63 78 82 62 92 38 92 22 82 12 63 18 37 33 15"],@[@"E",@"ef8eb3",@"29 28 20 18"],@[@"E",@"ef8eb3",@"56 51 23 23"],@[@"E",@"ef8eb3",@"25 73 19 12"]],
    @"cap": @[@[@"P",@"6abb75",@"7 58 15 31 32 14 60 13 80 28 87 51 92 64 64 74 16 71"],@[@"R",@"4a8b59",@"7 62 86 12 5"],@[@"E",@"fff2d0",@"36 26 28 28"],@[@"L",@"3d8758",@"45 34 45 47 56 47"]],
    @"ghost": @[@[@"P",@"f0eee9",@"15 83 15 41 24 22 42 13 58 13 76 22 85 41 85 83 70 70 55 83 40 70 25 83"],@[@"E",@"6d718b",@"32 36 12 18"],@[@"E",@"6d718b",@"56 36 12 18"],@[@"E",@"df87a0",@"44 62 12 8"]],
    @"shell": @[@[@"P",@"75b86a",@"10 62 14 39 30 21 50 13 70 21 86 39 90 62 75 78 25 78"],@[@"P",@"4c8153",@"50 17 67 35 62 59 38 59 33 35"],@[@"L",@"d9e7b9",@"10 62 90 62"],@[@"R",@"f0e2b5",@"19 65 62 17 6"]],
    @"flame": @[@[@"P",@"f39c5c",@"50 5 66 26 63 44 80 32 90 59 78 82 50 95 22 82 10 59 23 36 30 50 38 24"],@[@"P",@"ffe18d",@"50 44 67 64 60 83 40 83 33 64"]],
    @"pinkstar": @[@[@"E",@"ef9ec5",@"20 20 60 60"],@[@"E",@"f6bbd6",@"8 42 24 25"],@[@"E",@"f6bbd6",@"68 42 24 25"],@[@"E",@"bb587f",@"25 71 22 17"],@[@"E",@"bb587f",@"53 71 22 17"],@[@"E",@"383044",@"38 34 6 17"],@[@"E",@"383044",@"56 34 6 17"],@[@"L",@"9b456d",@"46 57 50 60 54 57"]],
    @"coin": @[@[@"E",@"e0a94d",@"18 7 64 86"],@[@"E",@"ffdd83",@"25 15 50 70"],@[@"R",@"bd8840",@"45 27 10 46 4"]]
}; });
    return shapes;
}
static NSDictionary<NSString *,NSArray<NSString *> *> *ZNThemeSignaturePairs(void) {
    static NSDictionary *pairs; static dispatch_once_t once;
    dispatch_once(&once,^{ pairs=@{
    @"zelda": @[@"triforce",@"sword"],
    @"mario": @[@"mushroom",@"star"],
    @"kirby": @[@"pinkstar",@"star"],
    @"luigi": @[@"cap",@"ghost"],
    @"peach": @[@"crown",@"heart"],
    @"bowser": @[@"shell",@"flame"],
    @"zelda-classic-edition": @[@"triforce",@"shield"],
    @"zelda-1": @[@"sword",@"rupee"],
    @"adventure-of-link": @[@"shield",@"sword"],
    @"a-link-to-the-past": @[@"sword",@"painting"],
    @"links-awakening": @[@"egg",@"harp"],
    @"ocarina-of-time": @[@"ocarina",@"triforce"],
    @"majoras-mask": @[@"mask",@"moon"],
    @"oracle-of-ages": @[@"harp",@"hourglass"],
    @"oracle-of-seasons": @[@"rod",@"leaf"],
    @"wind-waker": @[@"sail",@"wave"],
    @"minish-cap": @[@"hat",@"leaf"],
    @"twilight-princess": @[@"wolf",@"moon"],
    @"phantom-hourglass": @[@"hourglass",@"sail"],
    @"spirit-tracks": @[@"train",@"wave"],
    @"skyward-sword": @[@"bird",@"sword"],
    @"a-link-between-worlds": @[@"painting",@"rupee"],
    @"triforce-heroes": @[@"triforce",@"crown"],
    @"breath-of-the-wild": @[@"tablet",@"eye"],
    @"tears-of-the-kingdom": @[@"spiral",@"sword"],
    @"echoes-of-wisdom": @[@"wand",@"echo"]
}; });
    return pairs;
}
static UIColor *ZNThemeSignatureColor(NSString *hex) {
    unsigned value=0; [[NSScanner scannerWithString:hex] scanHexInt:&value];
    return [UIColor colorWithRed:((value>>16)&255)/255.0 green:((value>>8)&255)/255.0 blue:(value&255)/255.0 alpha:1];
}
static void ZNDrawThemeSignatureGlyph(NSString *name, CGRect frame) {
    CGContextRef ctx=UIGraphicsGetCurrentContext();
    NSArray *shapes=ZNThemeSignatureShapes()[name];
    if (!ctx || !shapes.count || CGRectIsEmpty(frame)) return;
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx,frame.origin.x,frame.origin.y);
    CGContextScaleCTM(ctx,frame.size.width/100.0,frame.size.height/100.0);
    for (NSArray<NSString *> *shape in shapes) {
        NSString *kind=shape[0]; UIColor *color=ZNThemeSignatureColor(shape[1]);
        NSArray<NSString *> *tokens=[shape[2] componentsSeparatedByString:@" "];
        UIBezierPath *p=nil;
        if ([kind isEqualToString:@"E"] || [kind isEqualToString:@"R"]) {
            CGRect r=CGRectMake(tokens[0].doubleValue,tokens[1].doubleValue,tokens[2].doubleValue,tokens[3].doubleValue);
            p=[kind isEqualToString:@"E"]?[UIBezierPath bezierPathWithOvalInRect:r]:[UIBezierPath bezierPathWithRoundedRect:r cornerRadius:tokens[4].doubleValue];
        } else {
            p=[UIBezierPath bezierPath]; [p moveToPoint:CGPointMake(tokens[0].doubleValue,tokens[1].doubleValue)];
            for (NSUInteger i=2;i+1<tokens.count;i+=2) [p addLineToPoint:CGPointMake(tokens[i].doubleValue,tokens[i+1].doubleValue)];
            if ([kind isEqualToString:@"P"]) [p closePath];
        }
        if ([kind isEqualToString:@"L"]) {
            [color setStroke]; p.lineWidth=4; p.lineCapStyle=kCGLineCapRound; p.lineJoinStyle=kCGLineJoinRound; [p stroke];
        } else { [color setFill]; [p fill]; }
    }
    CGContextRestoreGState(ctx);
}
