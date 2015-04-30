//use mouse to rotate canvas
//add your own sounds to x, y, z (maybe with InFeedback.ar)

s.options.memSize_(8192*4);
s.options.outDevice_("Soundflower (2ch)");
(
//--settings
// var width= Window.screenBounds.width, height= Window.screenBounds.height;
var width= Window.screenBounds.width, height= Window.screenBounds.height;

var fps= 60;
var buffersize= 512;
var scale= Window.screenBounds.width;
var perspective= 0.5;
var distance= 4;

//--
var win= Window("3d soundwave canvas", Rect(0 - width, 0, width, height), false).front.fullScreen;
var can= Canvas3D(win, Rect(0,  0, width, height)).scale_(scale).perspective_(perspective).distance_(distance)
//.background_(Color.new255(220,220,220,255));
//.background_(Color.new255(44,44,44,255));
//.background_(Color.new255(76,20,25,233));
.background_(Color.white(0.2,0.7));

var itemWave= Canvas3DItem.new
.color_(Color.new255(0,0,0,220))
.transforms = [
	Canvas3D.mTranslate(1,0.5,0),
];

var itemWave2= Canvas3DItem.new
.color_(Color.new255(0,0,155,120))
.transforms = [
    Canvas3D.mTranslate(-1,-0.5,0),
];

var itemWave3= Canvas3DItem.new
.color_(Color.new255(255,0,0,120))
.transforms = [
    Canvas3D.mTranslate(1,-0.5,0),
];

var itemWave4= Canvas3DItem.new
.color_(Color.new255(245,245,0,120))
.transforms = [
    Canvas3D.mTranslate(-1,0.5,0),
];

/*var itemWave5= Canvas3DItem.new
.color_(Color.new255(100,100,100,30))
.transforms = [
    Canvas3D.mTranslate(0,0,-10),
];*/


/* Paths */
var path  = [];
var path2 = [];
var path3 = [];
var path4 = [];
// var path5 = [];

/* Buffers */
var buffer;
var buffer2;
var buffer3;
var buffer4;
// var buffer5;

var rate = 0.005;

~window = win;

/* Add items */
can.add(itemWave4);
can.add(itemWave3);
can.add(itemWave2);
can.add(itemWave);
// can.add(itemWave5);

s.waitForBoot{
    buffer  = Buffer.alloc(s, buffersize, 2);
	buffer2 = Buffer.alloc(s, buffersize, 2);
	buffer3 = Buffer.alloc(s, buffersize, 2);
	buffer4 = Buffer.alloc(s, buffersize, 2);
	// buffer5 = Buffer.alloc(s, buffersize, 2);
    s.sync;
    {
        RecordBuf.ar(In.ar(2,2), buffer);
		RecordBuf.ar(In.ar(4,2), buffer2);
		RecordBuf.ar(In.ar(6,2), buffer3);
		RecordBuf.ar(In.ar(10,2), buffer4);
		// RecordBuf.ar(In.ar(0,2), buffer5);
		Silent.ar;
    }.play;
    s.sync;
    can.animate(fps, {|frame|
        buffer.getn(0, 1023, {|data| path= data.clump(3)});
        itemWave.paths= [path];

		buffer2.getn(0, 1023, {|data| path2= data.clump(3)});
		itemWave2.paths= [path2];

		buffer3.getn(0, 1023, {|data| path3= data.clump(3)});
		itemWave3.paths= [path3];

		buffer4.getn(0, 1023, {|data| path4= data.clump(3)});
		itemWave4.paths= [path4];
/*
		buffer5.getn(0, 1023, {|data| path5= data.clump(3)});
		itemWave5.paths= [path5];*/


    });


    CmdPeriod.doOnce({win.close; buffer.free});
};

)

