0 => int stemCounter;

0 => int rec;

// clock for the rhythm of a class/pattern yeilding thing.
class Phase {
    1::second => dur speed;
    1.0 => float multi; // how fast it is relative to speed
    
    BandedWG bwg =>     
    Pan2 pan => PRCRev r => Gain g => dac;

    // "test" => makeWvOut => WvOut2 test;
    if (rec) {
        pan => WvOut2 w => blackhole;
        stemFilename("phase") => w.wavFilename;
        null @=> w;
    }

    
    // 0.01 => r.mix;
    0.1 => r.mix;

    220 => bwg.freq;
    2 => bwg.preset;

    0.6 => g.gain;
		// 0 => g.gain;
    
    [
        0.5
    /*
        ,0.5
        ,0.5
        ,0.5
        ,1
        ,0.25
        ,0.25
        ,0.25
        ,0.25
        ,1
        ,0.5
        ,0.5
        */
    ] @=> float rhythm[];
    0 => int idx;
    
    fun void init(dur spd, float mult) {
        spd => speed;
        mult => multi;
    }
    
    // get how long before the next attack
    fun dur nextEvent() {
        rhythm[idx] => float currRhythm;
        
        (idx + 1) % rhythm.cap() => idx; // update index

        return currRhythm * speed * multi;
    }
    
    fun void execute() {
        // 0.25 => i.next;
                
        Math.random2f( 0, 1 ) => bwg.strikePosition;
        
        
        // Math.random2f( 0.96, 1.0) 
        // 0.96
        1.0 // this one is too much but will adding reverb work?
        => bwg.modesGain;

        Math.random2f( .7, 1 ) => bwg.pluck;
				
    }
}

fun dur executePhase(Phase p) {
    spork~ p.execute();
    return p.nextEvent();
}

class Tempo extends Event {
    dur tempo;
}

// The actual phaser object to do the 
// phasing && track tempo
class Phaser {
    Tempo tempo;
    0.4::second => dur speed;
    0.4 => float panAmount;
    
    Phase phase1;
    speed => phase1.speed;
    panAmount => phase1.pan.pan;
    
    Phase phase2;
    speed => phase2.speed;
    -1 * panAmount => phase2.pan.pan;
    // 0.0 => phase2.g.gain;
    
    1.03 => phase2.multi;
        
    fun void execute(Tempo tempo) {
        // <<< "phaser execute" >>>;
        
        phase1 => executePhase => dur d1;
        phase2 => executePhase => dur d2;
        
        while(true) {
            // execute current events
            if (d1 == 0::samp) {
                phase1 => executePhase => d1;
            }
            if (d2 == 0::samp) {
                phase2 => executePhase => d2;
            }
            
            // update dur values
            min(d1, d2) => dur nextEvent;
            d1 - nextEvent => d1;
            d2 - nextEvent => d2;
            
            // set up things for the next iteration            
            nextEvent => tempo.tempo;
            
            tempo.signal();
            nextEvent => now;
        }
    }
}

class SchedulerExecution extends Event {
    ScoreEvent currEvent;
}

// Tool to schedule events from the score into the phaser's tempo
class Scheduler {
    Phaser clock;
    // ScoreEvent score[];
    
    // 0 => int idx;
    
    SchedulerExecution e;
    Tempo tempo;
    // clock.setTempo(tempo);
    // Tempo tempo @=> clock.tempo;
    
    fun void execute() {
        spork~ clock.execute(tempo);
        
        while (true) {
            
            e => now;
            <<< "past scheduler execution event" >>>;
            e.currEvent @=> ScoreEvent currEvent;
            
            while(!currEvent.run(tempo.tempo)) {
                <<< "tempo", tempo.tempo >>>;
                tempo => now;
            }
            
            /*
            <<< tempo.tempo >>>;
            tempo => now;
            <<< "past tempo event" >>>;
            */
            
            /*
            while (clock.tempo.last() <= 0) {
                1::samp => now;
            }
            */
                                    
            <<< currEvent.print(), tempo.tempo, currEvent.d / 1::second, "second" >>>;

            // set up and execute the ScoreEvent
            tempo.tempo => currEvent.inst.tempo;
            spork~ currEvent.inst.execute();
                    
        }
    }
}


fun string stemFilename(string stemName) {
		stemName + stemCounter + ".wav" => string filename;
		stemCounter++;
		return filename;
}
// make a wvout for a specific stem
// fun int makeWvOut(string stem) {
// 		WvOut2 w => blackhole;

// 		"stems" => w.autoPrefix;
// 		stem + wvouts.cap() + ".wav" => w.wavFilename;
// 		// "test.wav" => w.wavFilename;

// 		null @=> w;

// 		wvouts << w;
		
// 		return wvouts.cap()-1;
// }

// individual events that happen in the score
class ScoreEvent {
    Instr inst;
    // tempo bounds to execute event
    0::samp => dur tMin;
    0::samp => dur tMax;
    
    // time until next event
    dur d; 
    
    fun int run(dur tempo) {
        if (tempo >= tMin && tempo <= tMax) {
            return 1;
        }
        return 0;
    }
    
    fun string print() {
        return inst.print();
    }
}

// get min of two durs
fun dur min(dur a, dur b) {
    if (a < b) {
        return a;
    }
    return b;
}

// base instrument class with tempo
class Instr {
    1::second => dur tempo;
    2::second => dur duration;

    fun void execute(){
        now => time start;
        start + duration => time end;
        
        Shakers shake => dac;
        
        while (now <= end) {
            1 => shake.noteOn;
            tempo => now;
        }
    }
    
    fun void update() {
        
    };
    
    fun string print() {
        return "Default\t";
    }
}

class Rest extends Instr {
    
    fun void execute() {
        return;
    }
    
    fun string print() {
        return "Rest\t";
    }
}

class GlobalBeat {
    440 => float freq;
    0.1 => float gain;
    1 => int power;
    
    dur tempo;
    
    Blit s1 => Envelope e => Gain g => dac;
    Blit s2 => e;
    
    2 => s1.harmonics => s2.harmonics;
    
    50::ms => e.duration;
    gain => g.gain;
        
    fun void execute() {
        if (!power) {
            e.keyOff();
            return;
        }
        
        Math.random2(1, 3) => s1.harmonics => s2.harmonics;
        1.0::second / tempo => float diff;
        freq => s1.freq;
        freq-diff => s2.freq;
        
        e.keyOn();
    }
    
    fun void setEnv() {
        if (power) {
            e.keyOn();
        } else {
            e.keyOff();
        }
    }
}

class Beat extends Instr {
    GlobalBeat b;
    
    float freq;
    float gain;
    int power;
    
    fun void execute() {
        freq => b.freq;
        gain => b.gain;
        power => b.power;
        tempo => b.tempo;
        
        b.execute();
    }
    
    fun string print() {
        return "Beat\t";
    }
}

Gain pluckGain => dac;

class Pluck extends Instr {
    
    330 => float freq;
    20 => float gain;
    dur d;
        
    [
    1.0
    ]
    @=> float rhythm[];

    0 => int grow; 
    
    
    fun void execute() {
        BandedWG bwg => Pan2 pan => pluckGain;
        Envelope attack => blackhole;
    
        gain => bwg.gain;
        Math.random2f(-1, 1) => pan.pan;

        now + d => time til;
        
        0.2 => attack.value;

        if (grow) {
                d => attack.duration;
        } else {
                d / 2.0 => attack.duration;
        }
        
        attack.keyOn();
        
        while (now < til) {            
            if (attack.last() == attack.target()) {
                attack.keyOff();
            }
        
            Math.random2f( 0, 1 ) => bwg.bowRate;
            Math.random2f( 0, 1 ) => bwg.bowPressure;
            Math.random2f( 0, 1 ) => bwg.strikePosition;
            freq => bwg.freq;
            
            attack.value() => bwg.pluck;
            
            Math.random2(0, rhythm.cap()-1) => int idx;
            
            rhythm[idx] * tempo => now;
        }
    }
    
    fun string print() {
        return "Pluck\t";
    }
}

class Bow extends Instr {
    BandedWG bwg => PRCRev r => Gain g => Pan2 pan => dac;
   
    0.01 => r.mix;
    440 => bwg.freq;
    2 => bwg.preset;
    1 => g.gain;
    
    fun void execute() {
        
        while (true) {
            Math.random2f( 0, 1 ) => bwg.bowRate;
            Math.random2f( 0, 1 ) => bwg.bowPressure;
            Math.random2f( 0, 1 ) => bwg.strikePosition;
            
            .8 => bwg.startBowing;
            4::second => now;
            1.0 => bwg.stopBowing;
            1::second => now;
        }
    };
    
    fun string print() {
        return "Bow\t";
    }

}

class Blitter extends Instr {
		// BlitSaw s => PRCRev r => dac;
		// // SinOsc s => PRCRev r => dac;
		dur d;

		// // initial settings
		// .1 => r.mix;
		// 0 => s.gain;
		// // set the harmonic
		// 2 => s.harmonics;

		// an array
		// [ 0, 1, 7, 11 ]
		// [ 0, 3 ]
		// [ -4, 0, 3 ]
		[0, 7, 8, 12]
		@=> int hi[];


		fun void execute() {
				now + d => time til;

				// while (now < til) {
						for (0 => int i; i < hi.cap(); i++) {
								BlitSaw s => Chorus c => Gen17 g17 => PRCRev r => dac;

								// [1.0, 0.0]
								[1., 0.5, 0.25, 0.125, 0.06, 0.03, 0.015]
								=> g17.coefs;
								0.1 => g17.gain;
								0.1 => g17.gain;
								
								
								0.5 => c.modDepth;
								20 => c.modFreq;
								// SinOsc s => PRCRev r => dac;

								// initial settings
								.1 => r.mix;
								0.2 => s.gain;
								// set the harmonic
								7 => s.harmonics;

								
								// Std.mtof( 45 + Math.random2(2, 3) * 12 +
								// hi[Math.random2(0,hi.size()-1)] ) => s.freq;
								Std.mtof( 45 + Math.random2(0, 1) * 12 +
								hi[i] ) => s.freq;								
						}

						20::second => now;
				// }

				// 0 => s.gain;
		}

		fun string print() {
        return "Blitter\t";
    }
}

fun ScoreEvent beat(GlobalBeat gb, float freq, dur duration, dur tMin, dur tMax) {
    // set up dependency chain
    ScoreEvent e;
    Beat b @=> e.inst;
    gb @=> b.b;
    
    // beat vals
    freq => b.freq;
    1 => b.power;
    
    
    duration => e.d;
    tMin => e.tMin;
    tMax => e.tMax;
    
    return e;
}

fun ScoreEvent beatOff(GlobalBeat gb) {
    // set up dependency chain
    ScoreEvent e;
    Beat b @=> e.inst;
    gb @=> b.b;

    // turn off
    0 => b.power;
    
    0::samp => e.d;
    0::samp => e.tMin;
    0::samp => e.tMax;
    
    return e;

}

fun ScoreEvent pluck(dur wait, dur length, dur tMin, dur tMax) {
    ScoreEvent e;
    Pluck p @=> e.inst;
    
    tMin => e.tMin;
    tMax => e.tMax;
    
    wait => e.d;
    length => p.d;
    
    return e;
}

fun ScoreEvent pluck(dur wait, dur length, float freq, dur tMin, dur tMax) {
    ScoreEvent e;
    Pluck p @=> e.inst;
    
    tMin => e.tMin;
    tMax => e.tMax;
    
    wait => e.d;
    length => p.d;

		freq => p.freq;
    
    return e;
}

fun ScoreEvent pluckGrow (dur wait, dur length, float freq, dur tMin, dur tMax) {
    ScoreEvent e;
    Pluck p @=> e.inst;
    
    tMin => e.tMin;
    tMax => e.tMax;
    
    wait => e.d;
    length => p.d;
		1 => p.grow;

		freq => p.freq;
    
    return e;
}

fun ScoreEvent rest(dur d) {
    ScoreEvent restEvent;
    Rest r @=> restEvent.inst;
    d => restEvent.d;
    
    return restEvent;
}

fun ScoreEvent bow(dur d) {
    ScoreEvent bowEvent;
    Bow b @=> bowEvent.inst;
    
    d => bowEvent.d;
    
    return bowEvent;
}

fun ScoreEvent blitter(dur wait, dur length, dur tMin, dur tMax) {
    ScoreEvent blitterEvent;
    Blitter b @=> blitterEvent.inst;

    tMin => blitterEvent.tMin;
    tMax => blitterEvent.tMax;
    
    wait => blitterEvent.d;
    length => b.d;
    
    return blitterEvent;
}

fun float scale(float inMin, float inMax, float outMin, float outMax, float val) {
    (val - inMin) / (inMax - inMin) => float inProportion;
    ((outMax - outMin) * inProportion) + outMin => float outVal;
    
    return outVal;
}

Scheduler s;
Phaser p @=> s.clock;
SchedulerExecution e @=> s.e;

GlobalBeat beat1;

fun void manageMidi(MidiIn in) {
    MidiMsg msg;
    
    dur pluckDur;

    while(true) {
        in => now;
     
         // receive midimsg(s)
        while( in.recv( msg ) )
        {
            // print content
            <<< msg.data1, msg.data2, msg.data3 >>>;
            if (msg.data2 == 41 && msg.data3 > 0) { // check for track focus 1 button press
                pluck(0::second, pluckDur, 220, 1000::samp, 15000::samp) @=> e.currEvent;
                e.signal();
            }
            
            if (msg.data2 == 49) { // set pluck duration val
                scale(0, 127, 1, 40, msg.data3) => float amount;
                amount::second => pluckDur;
            }

            if (msg.data2 == 42 && msg.data3 > 0) { // check for track focus 2 button press
                beat(beat1, 220, 0::samp, 5::ms, 400::ms) @=> e.currEvent;								
                e.signal();
            }
            
            if (msg.data2 == 74 && msg.data3 > 0) { // check for track focus 2 button press
                beat(beat1, 110, 0::samp, 5::ms, 400::ms) @=> e.currEvent;								
                e.signal();
            }

            if (msg.data2 == 77) { // adjust volume of global beat
                scale(0, 127, 0, 1, msg.data3) => pluckGain.gain;
            }

            
            if (msg.data2 == 78) { // adjust volume of global beat
                scale(0, 127, 0, 1, msg.data3) => beat1.g.gain;
            }
        }
   
    }
}



MidiIn midiIn;
"Launch Control XL" => string device; // device 0 is loopbe

// open midi receiver, exit on fail
if ( !midiIn.open(device) ) {
    <<< "Failed to open MIDI device" >>>;
    me.exit(); 
}

spork~ manageMidi(midiIn);

/*
ScoreEvent rest;
Rest r @=> rest.inst;
10::second => rest.d;
*/

spork~ s.execute();

/*
3::second => now;


pluck(10::second, 40::second, 220, 500::samp, 15000::samp) @=> e.currEvent;
e.signal();

3::second => now;
pluck(10::second, 40::second, 440, 3000::samp, 4000::samp) @=> e.currEvent;


<<< e.currEvent >>>;

e.signal();
*/

while (true) {
    1::second => now;
}