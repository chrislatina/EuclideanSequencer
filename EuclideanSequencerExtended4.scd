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
var window;
s = Server.default;

s.boot;
s.waitForBoot({
	//Modified Kick sound from DrumSynths.scd example
	SynthDef(\SOSkick,
		{ arg  amp = 0, out = 0,freq = 70;
			var mul = 0.8, mod_freq = 3, mod_index = 3, sustain = 0.4;
			var  drum_env = EnvGen.ar(Env.perc(0.005, sustain), 1.0, doneAction: 2);
			Out.ar([out,2],Pan2.ar(MembraneHexagon.ar(EnvGen.kr(Env.perc,amp,timeScale: 0.1, doneAction: 0)* PinkNoise.ar(0.15), freq/40000, MouseY.kr(0.9996, 0.9995, 1)),LFNoise0.kr(0.5,0.5)));
		}
	).add;

	//Modified snare909 sound from snare909.scd example
	SynthDef(\snare909,{ arg out =0,amp=0,mul=1,velocity=1, freq = 8040;
		var excitation, membrane;
		excitation = LPF.ar(WhiteNoise.ar(1), freq, 1) * (0.1*velocity);
		membrane = (
			/* Two simple enveloped oscillators represent the loudest resonances of the drum membranes */
			(LFTri.ar(330,0,1) * EnvGen.ar(Env.perc(0.0005,0.055),doneAction:0) * 0.25)
			+(LFTri.ar(185,0,1) * EnvGen.ar(Env.perc(0.0005,0.075),doneAction:0) * 0.25)
			/* Filtered white noise represents the snare */
			+(excitation * EnvGen.ar(Env.perc(0.0005,0.4),doneAction:2) * 0.2)
			+(HPF.ar(excitation, 523, 1) * EnvGen.ar(Env.perc(0.0005,0.283),doneAction:2) * 0.2)
		) * amp*0.2;



		membrane = EnvGen.kr(Env.perc,amp,timeScale: 0.1, doneAction: 0);
		Out.ar([0,4], Pan2.ar(MembraneHexagon.ar(membrane * PMOsc.ar(freq,2,6,2,0.2), freq/40000, MouseY.kr(0.9993, 0.999, 1)),LFNoise0.kr(0.2),1));
	}).add;


	//Hats synthesis modified from
	//"http://rumblesan.com/post/53271713518/drum-sounds-in-supercollider-part-1"
	SynthDef(\closedhat, { arg amp = 0, freq=8000;
		var hatosc, hatenv, hatnoise, hatoutput;

		hatenv = {Line.ar(1, 0, 0.25, doneAction:2)};
		hatoutput = (LFTri.ar([16000,MouseX.kr(15998,15999,\exponential)]) * hatenv);
		Out.ar([0,6],Pan2.ar(hatoutput, 0, amp));

	}).add;

	SynthDef(\openhat, {arg amp = 0, freq=4000;


		var hatosc, hatenv, hatnoise, hatoutput;
		hatnoise = {LPF.ar(WhiteNoise.ar(1),6000)};
		hatosc = {HPF.ar(hatnoise,freq)};
		hatenv = {Line.ar(1, 0, 0.06, doneAction:2)};
		hatoutput = (hatosc * hatenv);

		//Out.ar(0,Pan2.ar(hatoutput, LFNoise0.kr(0.03), amp));

		hatenv = EnvGen.ar(Env.perc(0.3,2),doneAction:2);
		hatoutput = (PMOsc.ar([MouseX.kr(12990,13000,'exponential'), MouseX.kr(MouseY.kr(12990,12998,\exponential),13000,'exponential')])* hatenv);
		Out.ar([0,10],Pan2.ar(hatoutput, 0, amp));

	}).add;


	// Create the pattern maker and set tempo.
	t = TempoClock(130/60.0);
	~velocity = 0.5;
	~patternMaker = { arg name, f, s, v, freq = [400];
		Pbind(
			\instrument, name,
			\dur, Prand([1, 0.2, 0.5, 3], inf),
			\amp, v*Pseq(Bjorklund(f,s),inf),
			\freq, Pshuf(freq,inf);
		).asStream;
	};
//Prand([60, 70, 80, 90, 100, 110, 120, 130, 140, 50, 220, 440, 8040, 7000, 6000, 1666], inf),

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
							numberbox.string.asInteger, numberbox2.value, ~velocity);}

					{\snare}{
						~snare = ~patternMaker.value(\snare909,
							numberbox.string.asInteger, numberbox2.value, ~velocity);}

					{\closedhat}{
						~closedhat = ~patternMaker.value(\closedhat,
							numberbox.string.asInteger, numberbox2.value, ~velocity);}

					{\openhat}{
						~openhat = ~patternMaker.value(\openhat,
							numberbox.string.asInteger, numberbox2.value, ~velocity);};
				});
			}.defer;
		};
		model3.addDependant(updater3);

		/*** Trigger Function ***/
		~triggerInstr = { arg instrument;

		};

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
						numberbox.string.asInteger, numberbox2.value, ~velocity, [50,12000, \exp, 1].asSpec.map(multislider.value));}

				{\snare}{
					~snare = ~patternMaker.value(\snare909,
						numberbox.string.asInteger, numberbox2.value, ~velocity, [50,12000, \exp, 1].asSpec.map(multislider.value));}

				{\closedhat}{
					~closedhat = ~patternMaker.value(\closedhat,
						numberbox.string.asInteger, numberbox2.value, ~velocity, [50,12000, \exp, 1].asSpec.map(multislider.value));}

				{\openhat}{
					~openhat = ~patternMaker.value(\openhat,
						numberbox.string.asInteger, numberbox2.value, ~velocity, [50,12000, \exp, 1].asSpec.map(multislider.value));};
				button.value_(0);
			}
		});

		//Multislider
		multislider = MultiSliderView(window,Rect(10,150,480-20,110));
		multislider.gap_(500/(numberbox2.value*2)); // width in pixels of each stick
		multislider.value=Array.fill(numberbox2.value, {|v| 0.0});
		multislider.action = { arg q; // size is set automatically when you set the value
			[50,12000, \exp, 1].asSpec.map(q.value).postln;
		};

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


	window = Window("Latina: Triggered Euclidean Sequencer", Rect(100,Window.screenBounds.height, 480, Window.screenBounds.height));
	window.addFlowLayout( 10@10, 20@5 );

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

	/* Tempo Trigger */
	//Button
	~tempTrigger = Button(window, 50@40)
		.states_([["Trigger"], ["Trigger"]])
		.font_(Font("Arial Rounded MT Bold", 12))
		.action_({|v|
		w.free;
		w = Synth(\clockTrigger, (["clock", t.tempo]));
		});

	~bus = Bus.audio(s,2);

	window.front;
	window.onClose_({
		w.free;z.free;s.freeAll;o.free;
		~row1.free; ~row2.free; ~row3.free; ~row4.free;
	});
});

//s.scope;
)

s.makeWindow;