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
s.options.outDevice_("Built-in Output");
//s.options.outDevice_("Soundflower (2ch)");

s.boot;


s.waitForBoot({

	SynthDef(\FreeVerb2x2, {|outbus, mix = 0.1, room = 0.7, damp = 0.8, amp = 1.0|
		var signal;

		signal = In.ar(outbus, 2);

		ReplaceOut.ar(outbus,
			FreeVerb2.ar( // FreeVerb2 - true stereo UGen
				signal[0], // Left channel
				signal[1], // Right Channel
				mix, room, damp, amp)); // same params as FreeVerb 1 chn version

	}).add;

	//Modified Kick sound from DrumSynths.scd example
	SynthDef(\SOSkick,
		{ arg  amp = 0, out = 0;
			var mul = 0.8, freq = 70, mod_freq = 3, mod_index = 3, sustain = 0.4, beater_noise_level = 0.03;
			var pitch_contour, drum_osc, drum_lpf, drum_env;
			var beater_source, beater_hpf, beater_lpf, lpf_cutoff_contour, beater_env;
			var kick_mix;
			pitch_contour = Line.kr(freq*2, freq, 0.02);
			drum_osc = PMOsc.ar(	pitch_contour,
				mod_freq,
				mod_index/1.3,
				mul: 1,
				add: 0);
			drum_lpf = LPF.ar(in: drum_osc, freq: 1000, mul: 1, add: 0);
			drum_env = drum_lpf * EnvGen.ar(Env.perc(0.005, sustain), 1.0, doneAction: 2);
			beater_source = WhiteNoise.ar(beater_noise_level);
			beater_hpf = HPF.ar(in: beater_source, freq: 500, mul: 1, add: 0);
			lpf_cutoff_contour = Line.kr(6000, 500, 0.03);
			beater_lpf = LPF.ar(in: beater_hpf, freq: lpf_cutoff_contour, mul: 1, add: 0);
			beater_env = beater_lpf * EnvGen.ar(Env.perc, 1.0, doneAction: 2);
			kick_mix = Mix.new([drum_env, beater_env]) * 2 * mul* amp;
			Out.ar(out, [kick_mix, kick_mix]);
		}
	).add;

	//Modified snare909 sound from snare909.scd example
	SynthDef(\snare909,{ arg out =0,amp=0,mul=1,velocity=1;
		var excitation, membrane;

		excitation = LPF.ar(WhiteNoise.ar(1), 7040, 1) * (0.1*velocity);
		membrane = (
			/* Two simple enveloped oscillators represent the loudest resonances of the drum membranes */
			(LFTri.ar(330,0,1) * EnvGen.ar(Env.perc(0.0005,0.055),doneAction:0) * 0.25)
			+(LFTri.ar(185,0,1) * EnvGen.ar(Env.perc(0.0005,0.075),doneAction:0) * 0.25)

			/* Filtered white noise represents the snare */
			+(excitation * EnvGen.ar(Env.perc(0.0005,0.4),doneAction:2) * 0.2)
			+(HPF.ar(excitation, 523, 1) * EnvGen.ar(Env.perc(0.0005,0.283),doneAction:0) * 0.2)

		) * amp*0.2;
		Out.ar(out, membrane!2);
	}).add;


	//Hats synthesis modified from
	//"http://rumblesan.com/post/53271713518/drum-sounds-in-supercollider-part-1"
	SynthDef(\closedhat, { arg amp = 0;
		var hatosc, hatenv, hatnoise, hatoutput;

		hatnoise = {LPF.ar(WhiteNoise.ar(1),6000)};

		hatosc = {HPF.ar(hatnoise,6000)};
		hatenv = {Line.ar(1, 0, 0.05, doneAction:2)};

		hatoutput = (hatosc * hatenv);

		Out.ar(0,
			Pan2.ar(hatoutput, 0, amp)
		)
	}).add;

	SynthDef(\openhat, {arg amp = 0;

		var hatosc, hatenv, hatnoise, hatoutput;

		hatnoise = {LPF.ar(WhiteNoise.ar(1),6000)};

		hatosc = {HPF.ar(hatnoise,4000)};
		hatenv = {Line.ar(1, 0, 0.2, doneAction:2)};

		hatoutput = (hatosc * hatenv);

		Out.ar(0,
			Pan2.ar(hatoutput, 0, amp)
		)
	}).add;


	t = TempoClock.default;
	t.tempo = 130/60.0;

	~velocity = 0.5;

	~patternMaker = { arg name, f, s, v;
		Pbind(
			\instrument, name,
			\dur, 0.25,
			\amp, v*Pseq(Bjorklund(f,s),inf)
		).asStream;
	};


	SynthDef(\sendTrig,{
		var trackb,trackh,trackq,temp, fft, in;

		//For onset-based beat tracking
		/*b = Buffer.alloc(s,1024,1); //for sampling rates 44100 and 48000
		in = AudioIn.ar(1);
		fft = FFT(b, in);

		#trackb,trackh,trackq,temp=BeatTrack.kr(fft, MouseX.kr(0.4999,1,0));*/

		SendTrig.kr(Impulse.kr((114/60.0)*4),0,1);

	}).add;

	// register to receive this message
	o = OSCFunc({ arg msg, time;
		//[time, msg].postln;
		switch(msg[2])
		{0}{
			~kick.next(Event.default).play;
			~snare.next(Event.default).play;
			~closedhat.next(Event.default).play;
			~openhat.next(Event.default).play;
		};
	},'/tr', s.addr);

	//Default values
	~kick      = ~patternMaker.value(\SOSkick, 0, 16, ~velocity);
	~closedhat = ~patternMaker.value(\closedhat, 0, 21, ~velocity);
	~openhat   = ~patternMaker.value(\openhat, 0, 33, ~velocity);
	~snare     = ~patternMaker.value(\snare909, 0, 18, ~velocity);

	w = Synth(\sendTrig);
	z = Synth(\FreeVerb2x2, [\outbus, 0, \mix, 0.2], addAction:\addToTail);

	// UI Function
	~generateUI = { arg window, instr, cc1, cc2, note;
		var slider, updater, model, setValueFunction, setValueFunction2, setValueFunction3, updater2, updater3, model2, model3, button, numberbox, numberbox2, ctrlSpec, ctrlSpec2;
		var control1, control2, triggernote;

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
		slider = Slider(window, Rect(110,0, 200, 50))
		.value_(model[\myValue])
		.action_({|view| setValueFunction.value(ctrlSpec.map(view.value))});

		//Number
		numberbox = StaticText(window, Rect(320, 0, 40,50))
		.string_(model[\myValue])
		.stringColor_(Color.white)
		.font_(Font("Arial Rounded MT Bold", 20))
		.action_({|view| setValueFunction.value(ctrlSpec.map(view.value))});

		//Number
		numberbox2 = EZNumber(window,  110@50, label:"Length", controlSpec: ctrlSpec2 )
		.setColors(Color.new255(60,140,60),Color.white,background: Color.new255(60,140,60), numTypingColor:Color.red)
		.font_(Font("Arial Rounded MT Bold", 14))
		.action_({|view|
			ctrlSpec2 = ControlSpec(0, view.value, \lin, 1, 0, );
			ctrlSpec = ControlSpec(0, ctrlSpec2.map(view.value), \lin, 1, 0, );
		});
		numberbox2.doAction;

		//Button
		button = Button(window, Rect(340,00, 50, 50))
		.states_([["Trigger"], ["Trigger"]])
		.font_(Font("Arial Rounded MT Bold", 12))
		.action_({|v|
			if(v.value==0){
			}{
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
				button.value_(0);
			}
		});

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
	//window.onClose_({model.removeDependant(updater); model2.removeDependant(updater2); model3.removeDependant(updater3); control1.remove; control2.remove; triggernote.remove; numberbox.remove;});
	};


	window = Window("Latina: Triggered Euclidean Sequencer", Rect(100,200, 500, 280));
	window.addFlowLayout( 10@10, 20@5 );

	window.view.background_(Color.new255(50,50,50));

	//Title
	StaticText(window, Rect(0, 0, 500, 30))
		.string_("Triggered Euclidean Sequencer")
		.align_(\center)
		.stringColor_(Color.white)
		.font_(Font("Arial Rounded MT Bold", 20));

	~row1 = ~generateUI.value(window, \kick,1, 2, 40 );
	~row2 = ~generateUI.value(window, \snare, 3, 4, 42);
	~row3 = ~generateUI.value(window, \closedhat, 5, 6, 36);
	~row4 = ~generateUI.value(window, \openhat, 7, 8, 38);


	window.front;
	window.onClose_({
		w.free;z.free;s.freeAll;o.free;
		~row1.free; ~row2.free; ~row3.free;
	});

	//s.makeWindow;
});
)