0 => int stemCounter;

0 => int rec;

// W  X  Y  Z  R   S   T  U  V  K  L  M   N   O  P  Q
  [0, 1, 2, 7, 8,  9, 10, 3, 4,11,12,13, 14, 15, 5, 6] @=> int channelMap[];


// clock for the rhythm of a class/pattern yeilding thing.
class Phase {
    1::second => dur speed;
    1.0 => float multi; // how fast it is relative to speed
    
    // should I make multiple pan objects to get better surround?
    BandedWG bwg => AmbPan3 pan => PRCRev r => Gain g => dac;

    // "test" => makeWvOut => WvOut2 test;
    if (rec) {
        pan => WvOut2 w => blackhole;
        stemFilename("phase") => w.wavFilename;
        null @=> w;
    }

    // add channelmap to pan
    channelMap => pan.channelMap;
    
    // 0.01 => r.mix;
    0.1 => r.mix;

    220 => bwg.freq;
    2 => bwg.preset;

    1 => g.gain;
		// 0 => g.gain;
    
    [
        0.5
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
        Math.random2f( 1, 1) => bwg.modesGain;

        Math.random2f( .7, 1 ) => bwg.pluck;
				
    }
}

fun dur executePhase(Phase p) {
    spork~ p.execute();
    return p.nextEvent();
}

// The actual phaser object to do the 
// phasing && track tempo
class Phaser {
    Impulse tempo => blackhole;
    0.4::second => dur speed;
    0 => float elevation;
    pi/2 => float azimuth;
    // 0.4 => float panAmount;
    
    Phase phase1;
    speed => phase1.speed;
    // panAmount => phase1.pan.pan;
    elevation => phase1.pan.elevation;
    azimuth => phase1.pan.azimuth;
    
    Phase phase2;
    speed => phase2.speed;
    elevation => phase2.pan.elevation;
    -1 * azimuth => phase2.pan.azimuth;
    // -1 * panAmount => phase2.pan.pan;
    // 0.0 => phase2.g.gain;
    
    1.03 => phase2.multi;
    
    fun void execute() {
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
            nextEvent / 1::samp => tempo.next; // cast dur to float
            // <<< "nextEvent", nextEvent >>>;
            nextEvent => now;
        }
    }
}

// Tool to schedule events from the score into the phaser's tempo
class Scheduler {
    Phaser clock;
    ScoreEvent score[];
    
    0 => int idx;
    
    fun void execute() {
        spork~ clock.execute();
        score[idx] @=> ScoreEvent currEvent;
        
        while (idx < score.cap()) {
            
            clock.tempo.last() => float currTempo;
            
            // skip and check tempo next time
            if (!currEvent.run(currTempo)) {
                1::samp => now;
                continue;
            }
                        
            <<< currEvent.print(), idx, clock.tempo.last()::samp, currEvent.d / 1::second, "second" >>>;

            // set up and execute the ScoreEvent
            clock.tempo.last()::samp => currEvent.inst.tempo;
            spork~ currEvent.inst.execute();
                        
            currEvent.d => now;
          
            idx++;
            if (idx < score.cap()) {
                score[idx] @=> currEvent;
            }
        }
    }
}


fun string stemFilename(string stemName) {
		stemName + stemCounter + ".wav" => string filename;
		stemCounter++;
		return filename;
}

// individual events that happen in the score
class ScoreEvent {
    Instr inst;
    // tempo bounds to execute event
    0 => float tMin;
    0 => float tMax;
    
    // time until next event
    dur d; 
    
    fun int run(float tempo) {
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
    
    Shakers shake => dac;
    
    fun void execute(){
        now => time start;
        start + duration => time end;
        
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
    
    SinOsc s1 => Envelope e => Gain g => dac;
    SinOsc s2 => e;

    if (rec) {
		g => WvOut2 w => blackhole;
		stemFilename("beat") => w.wavFilename;
		null @=> w;	
    } 
    
    50::ms => e.duration;
    gain => g.gain;
        
    fun void execute() {
        if (!power) {
            e.keyOff();
            return;
        }
        
        
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

class Pluck extends Instr {
    
    330 => float freq;
    7 => float gain;
    dur d;
    
    BandedWG bwg => Pan2 pan => dac;

    if (rec) {
		pan => WvOut2 w => blackhole;
		stemFilename("pluck") => w.wavFilename;
		null @=> w;		
    }
    
    gain => bwg.gain;
    Math.random2f(-0.4, 0.4) => pan.pan;
    
    // [1.0, 0.25, 0.25, 0.5] 
    [
    1.0
    // , 1.0, 1.0, 0.5
    ]
    @=> float rhythm[];

    0 => int grow; 
    
    Envelope attack => blackhole;
    
    fun void execute() {
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

fun ScoreEvent beat(GlobalBeat gb, float freq, dur duration, float tMin, float tMax) {
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
    0 => e.tMin;
    0 => e.tMax;
    
    return e;

}

fun ScoreEvent pluck(dur wait, dur length, float tMin, float tMax) {
    ScoreEvent e;
    Pluck p @=> e.inst;
    
    tMin => e.tMin;
    tMax => e.tMax;
    
    wait => e.d;
    length => p.d;
    
    return e;
}

fun ScoreEvent pluck(dur wait, dur length, float freq, float tMin, float tMax) {
    ScoreEvent e;
    Pluck p @=> e.inst;
    
    tMin => e.tMin;
    tMax => e.tMax;
    
    wait => e.d;
    length => p.d;

		freq => p.freq;
    
    return e;
}

fun ScoreEvent pluckGrow (dur wait, dur length, float freq, float tMin, float tMax) {
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

fun ScoreEvent blitter(dur wait, dur length, float tMin, float tMax) {
    ScoreEvent blitterEvent;
    Blitter b @=> blitterEvent.inst;

    tMin => blitterEvent.tMin;
    tMax => blitterEvent.tMax;
    
    wait => blitterEvent.d;
    length => b.d;
    
    return blitterEvent;
}

Scheduler s;
Phaser p @=> s.clock;

/*
ScoreEvent rest;
Rest r @=> rest.inst;
10::second => rest.d;
*/

GlobalBeat beat1;

// 13
0
=> int idx;
[
rest(10::second)
// rest(0::second)
, pluck(10::second, 25::second, 4000, 5000)
, pluck(7::second, 15::second, 4100, 4900)
, pluck(10::second, 100::second, 8000, 9000)
, pluck(3::second, 0.5::second, 4000, 5000) 
, pluck(3::second, 1::second, 4000, 5000)
, pluck(3::second, 1::second, 4000, 5000)
, pluck(1.5::second, 2::second, 4000, 5000)
, pluck(15::second, 55::second, 3000, 4000)
// , beat(beat1, 440, 4::second, 9000, 11000)
// , beat(beat1, 220, 4::second, 9000, 11000)
// , beat(beat1, 220, 4::second, 3000, 4000)
// , beat(beat1, 220, 4::second, 8000, 11000)
// , beatOff(beat1), rest(4::second)
// , beat(beat1, 220, 1::second, 4000, 8000)
// , beat(beat1, 220, 1::second, 2000, 8000)
// , beat(beat1, 220, 1::second, 2000, 8000) 
// , beat(beat1, 220, 3::second, 2000, 8000)
// , beat(beat1, 220, 1::second, 2000, 8000) 
// , beat(beat1, 220, 1::second, 8000, 10000) 
// , beatOff(beat1)
, pluck(10::second, 40::second, 220, 3000, 4000)
, pluck(10::second, 30::second, 347.7, 3000, 4000) // F
, pluck(10::second, 30::second, 880, 3000, 4000) // A
, pluck(3::second, 21::second, 1320, 12000, 18000) // E
, pluck(10::second, 15::second, 1100, 5000, 6000)
// , beat(beat1, 220, 4::second, 4000, 8000)
, beat(beat1, 260.7, 4::second, 400, 800) // C natural (make just inton)
// , beat(beat1, 220, 4::second, 4000, 8000)
, beat(beat1, 330, 4::second, 200, 400)
, beat(beat1, 220, 3::second, 400, 800)
, beat(beat1, 110, 4::second, 200, 400)
, beat(beat1, 260.7, 4::second, 800, 1200) // C natural
, beat(beat1, 330, 0.25::second, 200, 800)
, beat(beat1, 220, 3::second, 400, 800)
, pluck(3::second, 40::second, 1320, 12000, 18000)
, beat(beat1, 330, 0.25::second, 200, 800)
, beat(beat1, 260.7, 0.25::second, 200, 800)
, beat(beat1, 330, 0.25::second, 200, 800)
, beat(beat1, 195.6, 0.25::second, 200, 800) // G
, beat(beat1, 110, 4::second, 200, 400)
, pluckGrow(3::second, 33::second, 880, 3000, 4000) // clean this up
, pluckGrow(3::second, 33::second, 350, 3000, 4000)
, pluckGrow(3::second, 39::second, 440, 3000, 4000)
, pluckGrow(3::second, 24::second, 220, 2000, 3000)
, rest(22::second)
, beatOff(beat1)
// , rest(10::second)

// , bow(10::second)
// , blitter(0.5::second, 10::second, 4000, 5000)
// , blitter(2::second, 10::second, 6000, 7000)
// , blitter(3::second, 10::second, 3000, 4000)
// , blitter(2::second, 10::second, 700, 900)
// , blitter(10::second, 10::second, 6000, 7000)
, rest(15::second)
] @=> s.score;

// [ rest(300::second) ] @=> s.score;

idx => s.idx;

spork~ s.execute();

400::second => now;