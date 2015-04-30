// =====================================================================
// Christopher Latina
// Triggered Euclidean Sequencer
// Spring 2015
//
// Please recompile class library before each use
// To install dependant Bjorklund Quark, run: Quark.gui
// (highlight the command and press command enter)
// Select the Quark and then recompile the class library
// =====================================================================

(


/* Visualization */
var width= Window.screenBounds.width, height= Window.screenBounds.height;

var fps= 60;
var buffersize= 512;
var scale= Window.screenBounds.width;
var perspective= 1;
var distance= 1;

var window = Window("Chris Latina: Triggered Euclidean Sequencer", Rect(100,height, width, Window.screenBounds.height, false));


var can= Canvas3D(window, Rect(480,  0, width-480, height)).scale_(scale).perspective_(perspective).distance_(distance)
.background_(Color.green(0.1,0.8));

var itemWave= Canvas3DItem.new
.color_(Color.new255(200,200,200,210))
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


s = Server.default;

s.boot;

/* Synthdefs */
s.waitForBoot({
	SynthDef(\SOSkick,
		{ arg  amp = 0, out = 0,freq = 70;
			var hatosc, hatenv, hatoutput;

			hatenv = EnvGen.ar(Env.perc(0.003,0.3),doneAction:2);
			hatoutput = (PMOsc.ar([MouseX.kr(freq,freq+6,'exponential'), MouseX.kr(MouseY.kr(freq-5,freq,\exponential),freq+5,'exponential')],VOsc3.ar(freq/1000,20,30,40,0.3),1,6)* hatenv);
			Out.ar([0,2],Pan2.ar(hatoutput, PMOsc.ar(18,freq/12000,6), amp));
		}
	).add;

	SynthDef(\snare909,{ arg out =0,amp=0,mul=1,velocity=1, freq = 8040;
		var env = 0.5*EnvGen.ar(Env.perc(0.02,0.5),doneAction:2);
		var output = (PMOsc.ar([MouseX.kr(freq -10 ,freq,'exponential'), MouseX.kr(MouseY.kr(freq-8,freq-6,\exponential),freq,'exponential')],freq/300,3,4)* env);
		Out.ar([0],0.25*amp*Rotate2.ar(output[0],output[1],LFNoise0.kr(0.2)));
		Out.ar([4],1.5*amp*Rotate2.ar(output[0],output[1],LFNoise0.kr(0.2)));

	}).add;

	SynthDef(\closedhat, { arg amp = 0, freq=8000;
		var hatosc, hatenv, hatnoise, hatoutput;

		hatenv = {Line.ar(1, 0, 1, doneAction:2)};
		hatoutput = (PMOsc.ar(freq,MouseX.kr(freq -5 ,freq,'exponential'),2,4,1)*SinOsc.ar([6000,MouseX.kr(5998,5999,\exponential)]) * hatenv*0.6*amp);
		Out.ar([0],0.1*Pan2.ar(hatoutput,LFTri.kr(0.01)));
		Out.ar([6],0.6*Pan2.ar(hatoutput,LFTri.kr(0.01)));

	}).add;

	SynthDef(\openhat, {arg amp = 0, freq=4000;
			var hatosc, hatenv, hatoutput;
		var excitation = LPF.ar(WhiteNoise.ar(1), freq, 1) * (0.1);

		var env_perc = EnvGen.kr(Env.perc(0.0005,0.3),doneAction:2);
		var membrane = excitation * env_perc * amp;

		var env_gen;
		env_gen = EnvGen.kr(Env.perc,amp,timeScale: 0.4, doneAction: 0);
		Out.ar([0,10], 0.2*Pan2.ar(MembraneHexagon.ar(env_gen * PMOsc.ar(freq,2,4,2,0.2), freq/40000 + 0.012, MouseY.kr(0.9992, 0.999, 1)),LFNoise0.kr(0.2),0.25));

			/*hatenv = EnvGen.ar(Env.perc(0.003,1.5),doneAction:2);
			hatoutput = (PMOsc.ar([MouseX.kr(freq,freq+6,'exponential'), MouseX.kr(MouseY.kr(freq-5,freq,\exponential),freq+5,'exponential')],VOsc3.ar(freq/1000,20,30,40,0.3),1,6)* hatenv);
			Out.ar([0,10],Pan2.ar(hatoutput, PMOsc.ar(18,freq/12000,6), amp));*/
		}
	).add;


	// Create the pattern maker and set tempo.
	t = TempoClock(130/60.0);
	~velocity = 0.5;
	~patternMaker = { arg name, f, s, v, freq = [400];
		Pbind(
			\instrument, name,
			\dur, Prand([1, 0.2, 0.5, 3], inf),
			\amp, v*Pseq(Bjorklund(f,s),inf),
			\freq, Pseq(freq,inf);
		).asStream;
	};

	//OSC
	SynthDef(\clockTrigger,{ |clock|
		SendTrig.kr(Impulse.kr(clock*4),0,1);
	}).add;

	s.sync;

	// register to receive this message
	o = OSCFunc({ arg msg, time;
		//[time, msg].postln;
		switch(msg[2])
		{0}{
			~kick.next(Event.default).play(t);
			~snare.next(Event.default).play(t);
			~closedhat.next(Event.default).play(t);
			~openhat.next(Event.default).play(t);
		};
	},'/tr', s.addr);

	//Default values
	~kick      = ~patternMaker.value(\SOSkick, 0, 16, ~velocity, [70]);
	~closedhat = ~patternMaker.value(\closedhat, 0, 21, ~velocity, [8040]);
	~openhat   = ~patternMaker.value(\openhat, 0, 33, ~velocity, [8000]);
	~snare     = ~patternMaker.value(\snare909, 0, 18, ~velocity, [4000]);

	w = Synth(\clockTrigger, (["clock", t.tempo]));

	// UI Function
	~generateUI = { arg window, instr, cc1, cc2, note;
		var slider, updater, model, setValueFunction, setValueFunction2, setValueFunction3, updater2, updater3, model2, model3, button, numberbox, numberbox2, ctrlSpec, ctrlSpec2;
		var control1, control2, triggernote;
		var numSliders, multislider;
		var o;

		/*** MVC ***/
		//model
		model = (myValue: 0);
		setValueFunction = {|value|
			model [\myValue] = value;
			model.changed(\value, value);
		};

		//updater
		updater = {|theChanger, what, val|
			{
				if(what == \value, {
					numberbox.string_(val);
					slider.value_(val/numberbox2.value);
				});
			}.defer;
		};
		model.addDependant(updater);

		//model2
		model2 = (myValue: 0);
		setValueFunction2 = {|value|
			model2 [\myValue] = value;
			model2.changed(\value, value);
		};

		//updater2
		updater2 = {|theChanger, what, val|
			{
				if(what == \value, {
					ctrlSpec2 = ControlSpec(0, val, \lin, 1, 0, );
					ctrlSpec = ControlSpec(0, ctrlSpec2.map(val), \lin, 1, 0, );
					if(numberbox.string.asInteger > val){
						numberbox.string_(val);
						slider.doAction;
						slider.value_(ctrlSpec.map(val));
					};
					numberbox2.value_(val);
					numSliders=numberbox2.value;
				});
			}.defer;
		};
		model2.addDependant(updater2);

		//model3
		model3 = (myValue: 0);
		setValueFunction3 = {|value|
			model3 [\myValue] = value;
			model3.changed(\value, value);
		};

		//updater3
		updater3 = {|theChanger, what, val|
			{
				if(what == \value, {
					val.postln;
					switch(instr)
					{\kick}{
						~kick = ~patternMaker.value(\SOSkick,
							numberbox.string.asInteger, numberbox2.value, ~velocity,[50,13000, \exp, 1].asSpec.map(multislider.value));}

					{\snare}{
						~snare = ~patternMaker.value(\snare909,
							numberbox.string.asInteger, numberbox2.value, ~velocity,[50,13000, \exp, 1].asSpec.map(multislider.value));}

					{\closedhat}{
						~closedhat = ~patternMaker.value(\closedhat,
							numberbox.string.asInteger, numberbox2.value, ~velocity,[50,13000, \exp, 1].asSpec.map(multislider.value));}

					{\openhat}{
						~openhat = ~patternMaker.value(\openhat,
							numberbox.string.asInteger, numberbox2.value, ~velocity,[50,13000, \exp, 1].asSpec.map(multislider.value));};
				});
			}.defer;
		};
		model3.addDependant(updater3);

		/*** GUI ***/
		//view
		ctrlSpec = ControlSpec(0, 0, \lin, 1, 0, "");
		ctrlSpec2 = ControlSpec(0, 64, \lin, 1, 16, "" );

		//Slider
		slider = Slider(window, Rect(110,0, 200, 40))
		.value_(model[\myValue])
		.action_({|view| setValueFunction.value(ctrlSpec.map(view.value))});

		//Number
		numberbox = StaticText(window, Rect(320, 0, 40,40))
		.string_(model[\myValue])
		.stringColor_(Color.white)
		.font_(Font("Arial Rounded MT Bold", 20))
		.action_({|view| setValueFunction.value(ctrlSpec.map(view.value))});

		//Number
		numberbox2 = EZNumber(window,  110@40, label:"Length", controlSpec: ctrlSpec2 )
		.setColors(Color.new255(60,140,60),Color.white,background: Color.new255(60,140,60), numTypingColor:Color.red)
		.font_(Font("Arial Rounded MT Bold", 14))
		.action_({|view|
			ctrlSpec2 = ControlSpec(0, view.value, \lin, 1, 0, );
			ctrlSpec = ControlSpec(0, ctrlSpec2.map(view.value), \lin, 1, 0, );
		});
		numberbox2.doAction;

		//Button
		button = Button(window, Rect(340,0, 50, 40))
		.states_([["Trigger"], ["Trigger"]])
		.font_(Font("Arial Rounded MT Bold", 12))
		.action_({|v|
			if(v.value==0){
			}{
				switch(instr)
				{\kick}{
					~kick = ~patternMaker.value(\SOSkick,
						numberbox.string.asInteger, numberbox2.value, ~velocity, [50,13000, \exp, 1].asSpec.map(multislider.value));}

				{\snare}{
					~snare = ~patternMaker.value(\snare909,
						numberbox.string.asInteger, numberbox2.value, ~velocity, [50,13000, \exp, 1].asSpec.map(multislider.value));}

				{\closedhat}{
					~closedhat = ~patternMaker.value(\closedhat,
						numberbox.string.asInteger, numberbox2.value, ~velocity, [50,13000, \exp, 1].asSpec.map(multislider.value));}

				{\openhat}{
					~openhat = ~patternMaker.value(\openhat,
						numberbox.string.asInteger, numberbox2.value, ~velocity, [50,13000, \exp, 1].asSpec.map(multislider.value));};
				button.value_(0);
			}
		});

		//Multislider
		multislider = MultiSliderView(window,Rect(10,150,480-20,110));
		multislider.gap_(500/(numberbox2.value*2)); // width in pixels of each stick
		multislider.value=Array.fill(numberbox2.value, {|v| 0.5});
		multislider.colors_(Color.new255(150,0,0,255),Color.new255(150,0,0,255));
		multislider.action = { arg q; // size is set automatically when you set the value
			[50,13000, \exp, 1].asSpec.map(q.value).postln;
		};
		multislider.isFilled_(true);
		multislider.elasticMode_(1);
		//multislider.showIndex = true; // cursor mode


		control1 = CCResponder({ |src,chan,num,value|
			setValueFunction.value(ctrlSpec.map((value/127)));
			},
			nil, // any source
			nil, // any channel
			cc1, // CC number cc1
		);

		control2 = CCResponder({ |src,chan,num,value|
			setValueFunction2.value(value/2);
			},
			nil, // any source
			nil, // any channel
			cc2, // CC number cc2
		);

		triggernote = NoteOnResponder({ |src,chan,note,vel|
			setValueFunction3.value(note);
			},
			nil, // any source
			nil, // any channel
			note, // note number
			nil // any vel
		);
		//Cleanup
/*	window.onClose_({model.removeDependant(updater); model2.removeDependant(updater2); model3.removeDependant(updater3); control1.remove; control2.remove; triggernote.remove; numberbox.remove;});*/
	};

	//window.addFlowLayout( 10@10, 20@5 );
	window.view.decorator = FlowLayout( Rect(0,0,480,height), 10@10, 20@5 );

	window.view.background_(Color.new255(50,50,50));

	//Title
	StaticText(window, Rect(0, 0, 500, 30))
		.string_("Triggered Euclidean Sequencer")
		.align_(\center)
		.stringColor_(Color.white)
		.font_(Font("Arial Rounded MT Bold", 20));

	// Generate UI for each timbre with Trigger and CC control numbers
	~row1 = ~generateUI.value(window, \kick,      1, 2, 40);
	~row2 = ~generateUI.value(window, \snare,     3, 4, 42);
	~row3 = ~generateUI.value(window, \closedhat, 5, 6, 36);
	~row4 = ~generateUI.value(window, \openhat,   7, 8, 38);

	/* TEMPO */
	~tempoSpec = ControlSpec(20, 400, \lin, 1, 130, "" );
	~tempoControl = EZNumber(window,  110@40, label:"Tempo", controlSpec: ~tempoSpec )
		.setColors(Color.new255(60,140,60),Color.white,background: Color.new255(60,140,60), numTypingColor:Color.red)
		.font_(Font("Arial Rounded MT Bold", 14))
		.action_({|view|
		t.tempo = view.value/60.0;
		t.tempo.postln;
		});
	~tempoControl.doAction;

	/*** MVC ***/
	//model
	~tempoModel = (myValue: 0);
	~tempoSetValueFunction = {|value|
		~tempoModel [\myValue] = value;
		~tempoModel.changed(\value, value);
	};

	//updater
	~tempoUpdater = {|theChanger, what, val|
		{
			if(what == \value, {
				~tempoControl.value_(val);
				~tempoControl.doAction;
			});
		}.defer;
	};
	~tempoModel.addDependant(~tempoUpdater);

	~tempoCC = CCResponder({ |src,chan,num,value|
		~tempoSetValueFunction.value(value.linlin(0,127,20,400));
			},
			nil, // any source
			nil, // any channel
			9, // CC number 9
		);

	/* Tempo Trigger */
	//Button
	~tempTrigger = Button(window, 50@40)
		.states_([["Trigger"], ["Trigger"]])
		.font_(Font("Arial Rounded MT Bold", 12))
		.action_({|v|
		w.free;
		w = Synth(\clockTrigger, (["clock", t.tempo]));
		});

	~tempoMidiTrigger = NoteOnResponder({ |src,chan,note,vel|
		[src,chan,note,vel].postln;
			w.free;
		    w = Synth(\clockTrigger, (["clock", t.tempo]));
			},
		    nil, // any source
			nil, // any channel
			35, // note number
			nil // any vel
		);

	/* Visualization */
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


    CmdPeriod.doOnce({window.close; buffer.free;NoteOnResponder.removeAll; CCResponder.removeAll;});

	// ~bus = Bus.audio(s,2);

	window.front;
	window.onClose_({
		w.free;z.free;s.freeAll;o.free;
		~row1.free; ~row2.free; ~row3.free; ~row4.free; NoteOnResponder.removeAll; CCResponder.removeAll;
	});
});

//s.scope;
)

s.makeWindow;