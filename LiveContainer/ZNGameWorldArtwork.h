// Original game-world-inspired scenic illustrations. No extracted game files.
// Drawn directly into the existing cached skin bitmap, before controller keys.
#pragma once
static char ZNGameWorldArtworkKey;
static NSDictionary<NSString *,NSArray<NSString *> *> *ZNGameWorldProfiles(void) {
    static NSDictionary *profiles; static dispatch_once_t once;
    dispatch_once(&once,^{ profiles=@{
        @"mario": @[@"56b9ed",@"174b83",@"6bc34e",@"f8cf66",@"mushroom-kingdom",@"brick-pipes",@"mushroom",@"star"],
        @"luigi": @[@"25395f",@"102236",@"43896e",@"a3e7b7",@"haunted-house",@"graveyard",@"ghost",@"cap"],
        @"kirby": @[@"f3accd",@"8b71c6",@"9fe5ce",@"fff0a1",@"dream-hills",@"star-clouds",@"pinkstar",@"star"],
        @"peach": @[@"f4b9ce",@"ad648c",@"8fd7b3",@"ffe6a4",@"royal-garden",@"castle",@"crown",@"heart"],
        @"bowser": @[@"693b4d",@"231b2c",@"a94b36",@"faba58",@"lava",@"fortress",@"shell",@"flame"],
        @"zelda": @[@"386c57",@"16372f",@"77a66b",@"ebca78",@"forest",@"castle",@"sword",@"triforce"],
        @"zelda-classic-edition": @[@"8c793c",@"3c462e",@"aab36a",@"f5d77e",@"pixel-forest",@"temple",@"triforce",@"shield"],
        @"zelda-1": @[@"628a48",@"2a4e35",@"c8ab58",@"f9df91",@"pixel-forest",@"pixel-dungeon",@"sword",@"rupee"],
        @"adventure-of-link": @[@"8f6a73",@"413345",@"c18c62",@"efce99",@"palace",@"mountains",@"shield",@"sword"],
        @"a-link-to-the-past": @[@"73ad7a",@"2f574b",@"8d729e",@"f1cf77",@"forest",@"dark-world",@"sword",@"painting"],
        @"links-awakening": @[@"7ed0d6",@"3d8ba0",@"7fb269",@"fce4b9",@"island-egg",@"beach",@"egg",@"harp"],
        @"ocarina-of-time": @[@"568e73",@"254843",@"93b467",@"e6c77d",@"forest",@"temple",@"ocarina",@"triforce"],
        @"majoras-mask": @[@"6b548e",@"271f44",@"b37b77",@"eac37e",@"clock-town",@"moon-town",@"mask",@"moon"],
        @"oracle-of-ages": @[@"637fc7",@"2e376d",@"7e9bbe",@"ebd3ac",@"time-towers",@"river",@"harp",@"hourglass"],
        @"oracle-of-seasons": @[@"df9262",@"825046",@"9bb55b",@"f9da8d",@"autumn",@"winter",@"rod",@"leaf"],
        @"wind-waker": @[@"65c8dc",@"216d91",@"8ac7c0",@"f9dc9a",@"ocean",@"island",@"sail",@"wave"],
        @"minish-cap": @[@"73ad69",@"31583f",@"b9d47e",@"f6e7a3",@"giant-leaves",@"tiny-village",@"hat",@"leaf"],
        @"twilight-princess": @[@"594d65",@"211e2b",@"736678",@"f4a44e",@"twilight",@"ruins",@"wolf",@"moon"],
        @"phantom-hourglass": @[@"59b9cb",@"245e7c",@"92bcab",@"f3cf88",@"ocean",@"sea-temple",@"hourglass",@"sail"],
        @"spirit-tracks": @[@"87b2cd",@"345f70",@"84b36d",@"f4cc84",@"railway",@"railway-town",@"train",@"wave"],
        @"skyward-sword": @[@"91c6e7",@"536fa8",@"90bd86",@"ffe1a1",@"sky-islands",@"sky-temple",@"bird",@"sword"],
        @"a-link-between-worlds": @[@"b486b7",@"513d70",@"7cb099",@"f1d58d",@"painted-hyrule",@"dark-world",@"painting",@"rupee"],
        @"triforce-heroes": @[@"d1a563",@"76513f",@"82a58f",@"ffe4a0",@"royal-garden",@"palace",@"triforce",@"crown"],
        @"breath-of-the-wild": @[@"517f89",@"203946",@"9bb183",@"79e3ff",@"hyrule-field",@"sheikah-shrine",@"tablet",@"eye"],
        @"tears-of-the-kingdom": @[@"76a897",@"304c4a",@"b7ad70",@"a7f7c7",@"sky-islands",@"zonai-ruins",@"spiral",@"sword"],
        @"echoes-of-wisdom": @[@"bf93c9",@"62558a",@"94c1a7",@"ffe5a0",@"storybook",@"echo-rift",@"wand",@"echo"]
    }; });
    return profiles;
}
static UIColor *ZNWorldColor(NSString *hex) { return ZNThemeSignatureColor(hex); }
static void ZNWRect(CGFloat x,CGFloat y,CGFloat w,CGFloat h,UIColor *c) {
    [c setFill]; UIRectFill(CGRectMake(x,y,w,h));
}
static void ZNWOval(CGFloat x,CGFloat y,CGFloat w,CGFloat h,UIColor *c) {
    [c setFill]; [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(x,y,w,h)] fill];
}
static void ZNWPath(NSString *coords,UIColor *c,BOOL fill,CGFloat width) {
    NSArray *v=[coords componentsSeparatedByString:@" "]; UIBezierPath *p=[UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake([v[0] doubleValue],[v[1] doubleValue])];
    for(NSUInteger i=2;i+1<v.count;i+=2)
        [p addLineToPoint:CGPointMake([v[i] doubleValue],[v[i+1] doubleValue])];
    if(fill){[p closePath];[c setFill];[p fill];}
    else{[c setStroke];p.lineWidth=width;p.lineJoinStyle=kCGLineJoinRound;p.lineCapStyle=kCGLineCapRound;[p stroke];}
}
static void ZNWGlyph(NSString *glyph,CGFloat x,CGFloat y,CGFloat side) {
    ZNDrawThemeSignatureGlyph(glyph,CGRectMake(x,y,side,side));
}
static BOOL ZNWIn(NSString *s,NSArray *a) { return [a containsObject:s]; }
static void ZNWCloud(CGFloat x,CGFloat y,UIColor *c) {
    ZNWOval(x,y+3,23,10,c); ZNWOval(x+5,y,14,13,c);
}
static void ZNWTree(CGFloat x,CGFloat y,CGFloat size,UIColor *leaf,BOOL pixel) {
    ZNWRect(x+size*.44,y+size*.45,size*.13,size*.55,ZNWorldColor(@"82604d"));
    if(pixel){
        ZNWRect(x+size*.15,y,size*.70,size*.55,leaf);
        ZNWRect(x,y+size*.18,size,size*.38,leaf);
    } else {
        ZNWOval(x,y,size*.72,size*.65,leaf); ZNWOval(x+size*.30,y+size*.06,size*.7,size*.63,leaf);
        ZNWOval(x+size*.15,y-size*.12,size*.7,size*.7,leaf);
    }
}
static void ZNWBuilding(CGFloat x,CGFloat y,CGFloat w,CGFloat h,UIColor *wall,UIColor *roof,BOOL tower) {
    ZNWRect(x,y,w,h,wall);
    if(tower){
        for(int i=0;i<3;i++) ZNWRect(x+i*w/3,y-4,w/5,5,wall);
    }else{
        UIBezierPath *p=[UIBezierPath bezierPath];[p moveToPoint:CGPointMake(x-2,y)];[p addLineToPoint:CGPointMake(x+w*.5,y-w*.45)];[p addLineToPoint:CGPointMake(x+w+2,y)];[p closePath];[roof setFill];[p fill];
    }
    for(int i=0;i<2;i++) ZNWRect(x+w*(.18+i*.48),y+h*.24,w*.15,h*.19,roof);
    ZNWRect(x+w*.39,y+h*.65,w*.22,h*.35,roof);
}
// Normalized 100x200 panel. Every world has a different environment,
// horizon, architectural silhouettes and recognizable in-world objects.
static void ZNWScene(NSString *scene, NSArray<NSString *> *p, CGRect frame, NSString *prop, BOOL right) {
    CGContextRef ctx=UIGraphicsGetCurrentContext(); if(!ctx||CGRectIsEmpty(frame))return;
    CGContextSaveGState(ctx); CGContextClipToRect(ctx,frame);
    CGContextTranslateCTM(ctx,frame.origin.x,frame.origin.y);
    CGContextScaleCTM(ctx,frame.size.width/100,frame.size.height/200);
    UIColor *sky=ZNWorldColor(p[0]),*deep=ZNWorldColor(p[1]),*land=ZNWorldColor(p[2]),*gold=ZNWorldColor(p[3]);
    UIColor *white=[UIColor colorWithWhite:1 alpha:.78],*shade=[deep colorWithAlphaComponent:.85];
    StrataNxBuiltGradient([UIBezierPath bezierPathWithRect:CGRectMake(0,0,100,200)],sky,deep);
    BOOL ocean=ZNWIn(scene,@[@"ocean",@"island",@"beach",@"sea-temple",@"river"]);
    BOOL skyworld=ZNWIn(scene,@[@"sky-islands",@"sky-temple",@"star-clouds"]);
    BOOL night=ZNWIn(scene,@[@"haunted-house",@"graveyard",@"moon-town",@"twilight",@"dark-world",@"echo-rift"]);
    BOOL pixel=ZNWIn(scene,@[@"pixel-forest",@"pixel-dungeon"]);
    BOOL mario=ZNWIn(scene,@[@"mushroom-kingdom",@"brick-pipes"]);
    BOOL stone=ZNWIn(scene,@[@"temple",@"palace",@"fortress",@"ruins",@"sheikah-shrine",@"zonai-ruins",@"time-towers",@"pixel-dungeon"]);
    if(night){
        ZNWOval(62,10,26,26,[gold colorWithAlphaComponent:.65]);
        for(int i=0;i<16;i++) ZNWOval((i*37+11)%96,8+(i*23)%70,1.2,1.2,white);
    }else if(!stone){
        ZNWCloud(8,20,white);ZNWCloud(67,43,[white colorWithAlphaComponent:.55]);
    }
    if(ocean){
        ZNWRect(0,89,100,111,[sky colorWithAlphaComponent:.6]);
        for(int i=0;i<10;i++){
            CGFloat y=95+i*11;
            UIBezierPath *wave=[UIBezierPath bezierPath];[wave moveToPoint:CGPointMake(-5,y)];
            for(int j=0;j<5;j++)[wave addQuadCurveToPoint:CGPointMake(15+j*23,y) controlPoint:CGPointMake(4+j*23,y+(j%2?5:-5))];
            wave.lineWidth=1.4;[[white colorWithAlphaComponent:.42] setStroke];[wave stroke];
        }
        if(![scene isEqualToString:@"ocean"]){
            ZNWOval(-18,118,104,44,gold);ZNWOval(-10,111,88,34,land);
            ZNWTree(9,80,24,land,NO); ZNWTree(46,88,20,land,NO);
        }else{ZNWGlyph(@"sail",9,95,48);}
        if([scene isEqualToString:@"river"]) ZNWPath(@"0 112 19 102 35 111 25 129 0 141",land,YES,0);
        if([scene isEqualToString:@"sea-temple"]) ZNWBuilding(59,83,32,45,gold,deep,YES);
    }else if(skyworld){
        for(int i=0;i<3;i++){
            CGFloat x=5+i*29,y=52+i*36;
            ZNWPath([NSString stringWithFormat:@"%g %g %g %g %g %g %g %g",x,y,x+35,y,x+24,y+21,x+10,y+29],deep,YES,0);
            ZNWOval(x-1,y-5,36,10,land);
            if(i==1)ZNWBuilding(x+7,y-21,19,18,gold,deep,YES);
            else ZNWTree(x+11,y-18,17,land,NO);
        }
        ZNWCloud(13,153,white);ZNWCloud(73,178,white);
    }else if([scene isEqualToString:@"lava"]){
        ZNWPath(@"0 148 22 49 46 142 66 70 100 154 100 200 0 200",shade,YES,0);
        ZNWPath(@"0 172 30 163 56 173 83 159 100 164 100 200 0 200",ZNWorldColor(@"d75736"),YES,0);
        ZNWPath(@"0 186 23 175 45 187 80 178 100 182",gold,NO,3);
        ZNWGlyph(@"flame",49,84,34);
    }else{
        ZNWPath(@"0 122 18 70 40 113 62 48 100 111 100 200 0 200",[land colorWithAlphaComponent:.48],YES,0);
        ZNWPath(@"0 153 23 117 47 145 77 103 100 143 100 200 0 200",land,YES,0);
        ZNWPath(@"0 176 20 168 48 179 75 158 100 166 100 200 0 200",shade,YES,0);
        if(mario){
            ZNWOval(-18,110,58,70,land); ZNWOval(62,95,50,82,land);
            for(int i=0;i<3;i++){
                CGFloat x=9+i*29,y=63+(i%2)*9;
                ZNWRect(x,y,21,21,ZNWorldColor(@"b67943"));
                ZNWRect(x+1,y+1,19,18,gold);
                [@"?" drawInRect:CGRectMake(x+5,y+1,15,19) withAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:16],NSForegroundColorAttributeName:deep}];
                ZNWGlyph(@"coin",x+4,y-24,13);
            }
            ZNWRect(65,137,24,49,ZNWorldColor(@"299c51")); ZNWRect(63,132,28,10,ZNWorldColor(@"5dd06e"));
            ZNWRect(68,143,5,37,[white colorWithAlphaComponent:.32]);
            for(int i=0;i<5;i++)ZNWRect(i*20,187,19,13,ZNWorldColor(@"a96b41"));
            ZNWGlyph(@"mushroom",10,129,30);
        }else if(stone){
            UIColor *wall=[gold colorWithAlphaComponent:.60];
            for(int i=0;i<3;i++){
                CGFloat x=9+i*30,y=72+(i%2)*13;
                ZNWRect(x,y,18,85,wall);ZNWRect(x-3,y-3,24,7,gold);
                for(int k=0;k<5;k++)ZNWRect(x+2,y+10+k*14,14,1.1,shade);
            }
            ZNWRect(5,156,90,8,wall);ZNWRect(0,169,100,8,shade);
            if(ZNWIn(scene,@[@"sheikah-shrine",@"zonai-ruins"])){
                for(int i=0;i<4;i++)ZNWPath([NSString stringWithFormat:@"%d 84 %d 99 %d 113 %d 130",12+i*23,18+i*23,12+i*23,18+i*23],gold,NO,1.7);
                ZNWGlyph([scene isEqualToString:@"sheikah-shrine"]?@"eye":@"spiral",28,118,44);
            }else if([scene isEqualToString:@"pixel-dungeon"]){
                for(int row=0;row<4;row++)for(int col=0;col<5;col++)ZNWRect(col*20,row*10+35,19,9,[wall colorWithAlphaComponent:.36]);
            }
        }else if(ZNWIn(scene,@[@"castle",@"royal-garden",@"haunted-house",@"clock-town",@"moon-town",@"railway-town",@"tiny-village",@"storybook",@"painted-hyrule"])){
            BOOL haunted=[scene isEqualToString:@"haunted-house"];
            ZNWBuilding(9,105,31,49,haunted?shade:gold,deep,haunted);
            ZNWBuilding(57,88,34,68,haunted?shade:[land colorWithAlphaComponent:.9],deep,haunted||[scene isEqualToString:@"castle"]);
            if(ZNWIn(scene,@[@"clock-town",@"moon-town"])){
                ZNWBuilding(34,57,25,101,gold,deep,YES);
                ZNWOval(38,65,17,17,white);ZNWPath(@"46 68 46 74 51 76",deep,NO,1.5);
            }
            if([scene isEqualToString:@"royal-garden"]){
                for(int i=0;i<7;i++)ZNWGlyph(@"flower",3+i*14,173,12);
            }
            if([scene isEqualToString:@"haunted-house"]) ZNWGlyph(@"ghost",12,50,25);
        }else if([scene isEqualToString:@"railway"]){
            ZNWPath(@"5 200 43 105 55 105 92 200",gold,NO,2);
            for(int i=0;i<8;i++){CGFloat y=118+i*11,span=10+i*5;ZNWRect(50-span,y,span*2,2.5,shade);}
            ZNWGlyph(@"train",24,127,50);
        }else if([scene isEqualToString:@"island-egg"]){
            ZNWGlyph(@"egg",31,42,39);ZNWTree(5,125,33,land,NO);ZNWTree(68,122,27,land,NO);
        }else if(ZNWIn(scene,@[@"twilight",@"echo-rift",@"dark-world"])){
            for(int i=0;i<9;i++){
                CGFloat x=(i*31)%94,y=32+(i*23)%120;
                ZNWRect(x,y,4+(i%3),17,[gold colorWithAlphaComponent:.60]);
                ZNWRect(x+5,y+8,9,2,[gold colorWithAlphaComponent:.35]);
            }
            ZNWPath(@"13 192 29 132 24 99 56 68 47 44 81 18",gold,NO,2.7);
        }else if([scene isEqualToString:@"graveyard"]){
            for(int i=0;i<4;i++){CGFloat x=8+i*23;ZNWRect(x,133+i%2*12,15,28,shade);ZNWOval(x,128+i%2*12,15,12,shade);}
        }else if([scene isEqualToString:@"giant-leaves"]){
            for(int i=0;i<4;i++)ZNWGlyph(@"leaf",i%2?45:-5,32+i*38,59);
        }else if([scene isEqualToString:@"winter"]){
            ZNWPath(@"0 130 18 72 40 116 62 48 100 111 100 200 0 200",white,YES,0);
            for(int i=0;i<16;i++)ZNWOval((i*29)%98,15+(i*17)%150,2,2,white);
        }else{
            UIColor *foliage=[scene isEqualToString:@"autumn"]?ZNWorldColor(@"e49b52"):land;
            for(int i=0;i<4;i++)ZNWTree(2+i*24,105+(i%2)*16,25,foliage,pixel);
            if([scene isEqualToString:@"hyrule-field"]){
                ZNWRect(66,81,5,70,shade);ZNWRect(61,75,15,8,gold);ZNWPath(@"68 76 68 49",gold,NO,1.5);
            }
            if([scene isEqualToString:@"dream-hills"]){ZNWGlyph(@"star",12,51,24);ZNWGlyph(@"star",69,77,19);}
        }
    }
    // The actual game motifs are integrated directly into the scenery,
    // not badges on the bezel. They are behind the independent controls.
    CGFloat propY=right?22:150;
    if([scene isEqualToString:@"brick-pipes"]||[scene isEqualToString:@"mushroom-kingdom"]) propY=right?20:145;
    ZNWGlyph(prop,right?57:9,propY,33);
    CGContextRestoreGState(ctx);
}
static void ZNDrawGameWorldPlate(NSArray<NSString *> *p, BOOL portrait, CGRect all) {
    UIColor *sky=ZNWorldColor(p[0]),*deep=ZNWorldColor(p[1]),*gold=ZNWorldColor(p[3]);
    CGFloat w=all.size.width,h=all.size.height;
    StrataNxBuiltGradient([UIBezierPath bezierPathWithRect:all],sky,deep);
    CGRect left=portrait?CGRectMake(0,h*.435,w*.5,h*.565):CGRectMake(0,0,w*.255,h);
    CGRect right=portrait?CGRectMake(w*.5,h*.435,w*.5,h*.565):CGRectMake(w*.745,0,w*.255,h);
    ZNWScene(p[4],p,left,p[6],NO);ZNWScene(p[5],p,right,p[7],YES);
    // Upper and lower centre trim, original ornamental finish; no touch changes.
    UIColor *trim=[gold colorWithAlphaComponent:.8];
    [trim setStroke];UIBezierPath *outline=[UIBezierPath bezierPathWithRect:CGRectInset(all,portrait?12:105,portrait?12:137)];outline.lineWidth=portrait?4:5;[outline stroke];
    CGRect game=portrait?CGRectMake(37,138,847,661):CGRectMake(463,169,863,574);
    CGRect rim=CGRectInset(game,-9,-9);
    [deep setFill];UIRectFill(rim);[trim setStroke];UIBezierPath *edge=[UIBezierPath bezierPathWithRect:rim];edge.lineWidth=5;[edge stroke];
    [UIColor.blackColor setFill];UIRectFill(game);
    if(portrait){
        // A narrow in-world decorative frieze between the game and controls.
        for(int i=0;i<7;i++) ZNWGlyph(i%2?p[6]:p[7],w*(.20+i*.086),h*.414,w*.045);
    }else{
        for(int i=0;i<9;i++){
            CGFloat x=w*(.28+i*.052);
            ZNWPath([NSString stringWithFormat:@"%g %g %g %g %g %g",x-6,h*.151,x,h*.144,x+6,h*.151],trim,NO,2.1);
        }
    }
}
