//use mouse to rotate canvas
//add your own sounds to x, y, z (maybe with InFeedback.ar)

s.options.memSize_(8192*4);
s.options.outDevice_("Soundflower (2ch)");
(
//--settings
// var width= Window.screenBounds.width, height= Window.screenBounds.height;
var width= 1280, height= 720;

var fps= 60;
var buffersize= 512;
var scale= Window.screenBounds.width;
var perspective= 1;
var distance= 1;

//--
var win= Window("3d soundwave canvas", Rect(0, 0, width, height), false).front;

var can= Canvas3D(win, Rect(0,  0, width, height)).scale_(scale).perspective_(perspective).distance_(distance)
//.background_(Color.new255(220,220,220,255));
//.background_(Color.new255(44,44,44,255));
//.background_(Color.new255(76,20,25,233));
.background_(Color.black(0.2,0.7));

var itemWave= Canvas3DItem.new
.color_(Color.new255(100,100,100,255))
.transforms = [
    Canvas3D.mTranslate(0,0,-10),
];


/* Paths */
var path  = [];
/* Buffers */
var buffer;
var rate = 0.005;

/* Add items */
can.add(itemWave);

s.waitForBoot{
    buffer  = Buffer.alloc(s, buffersize, 2);

    s.sync;
    {
        RecordBuf.ar(In.ar(0,2), buffer);
		Silent.ar;
    }.play;
    s.sync;
    can.animate(fps, {|frame|

		buffer.getn(0, 1023, {|data| path= data.clump(3)});
        itemWave.paths= [path];

		can.transforms = [
            Canvas3D.mRotateY(frame/100 + (sin(frame/70)*2) %2pi),
            Canvas3D.mRotateX(frame/100%2pi),
            Canvas3D.mScale(sin(frame/80*4)*0.3+1)
        ];
        itemWave.transforms = [
            Canvas3D.mRotateY(frame/60%2pi)
        ];


    });

	 can.mouseMoveAction = {|v,x,y, mod|

        can.transforms = [
            Canvas3D.mRotateY(x / -200 % 2pi),
            Canvas3D.mRotateX(y / 200 % 2pi)
        ];
        can.refresh;
    };


    CmdPeriod.doOnce({win.close; buffer.free});
};
)


