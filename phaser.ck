// clock for the rhythm of a class/pattern yeilding thing.
class Phase {
    1::second => dur speed;
    1.0 => float multi; // how fast it is relative to speed
    
    BandedWG bwg => PRCRev r => Gain g => Pan2 pan => dac;
    
    0.01 => r.mix;

    220 => bwg.freq;
    2 => bwg.preset;
    0.7 => g.gain;
    
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
    0.4 => float panAmount;
    
    Phase phase1;
    speed => phase1.speed;
    panAmount => phase1.pan.pan;
    
    Phase phase2;
    speed => phase2.speed;
    -1 * panAmount => phase2.pan.pan;
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
            
            <<< "Event", idx, currEvent.d / 1::second >>>;
            
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
}

class Rest extends Instr {
    
    fun void execute() {
        return;
    }
}

class GlobalBeat {
    440 => float freq;
    0.1 => float gain;
    1 => int power;
    
    dur tempo;
    
    SinOsc s1 => Envelope e => Gain g => dac;
    SinOsc s2 => e;
    
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
}

class Pluck extends Instr {
    
    330 => float freq;
    7 => float gain;
    dur d;
    
    BandedWG bwg => dac;
    gain => bwg.gain;
    
    // [1.0, 0.25, 0.25, 0.5] 
    [
    1.0
    // , 1.0, 1.0, 0.5
    ]
    @=> float rhythm[];
    
    Envelope attack => blackhole;


    
    fun void execute() {
        now + d => time til;
        
        0.2 => attack.value;
        d / 2.0 => attack.duration;
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

fun ScoreEvent rest(dur d) {
    ScoreEvent restEvent;
    Rest r @=> restEvent.inst;
    d => restEvent.d;
    
    return restEvent;
}

Scheduler s;
Phaser p @=> s.clock;

/*
ScoreEvent rest;
Rest r @=> rest.inst;
10::second => rest.d;
*/

GlobalBeat beat1;

3 => int idx;
[
rest(10::second)
// rest(0::second)
, pluck(10::second, 20::second, 4000, 5000)
, pluck(5::second, 10::second, 4100, 4900)
, pluck(10::second, 60::second, 8000, 9000)
, pluck(10::second, 40::second, 4000, 5000)
, beat(beat1, 220, 4::second, 10000, 11000)
, beat(beat1, 220, 4::second, 9000, 11000)
, beat(beat1, 220, 4::second, 8000, 11000)
, beatOff(beat1), rest(4::second)
, beat(beat1, 220, 1::second, 4000, 8000)
, beat(beat1, 220, 1::second, 2000, 8000)
, beat(beat1, 220, 1::second, 2000, 8000) 
, beat(beat1, 220, 3::second, 2000, 8000)
, beat(beat1, 220, 1::second, 2000, 8000) 
, beat(beat1, 220, 1::second, 8000, 10000) 
, beatOff(beat1)
, rest(10::second)
] @=> s.score;

idx => s.idx;




spork~ s.execute();

100::second => now;