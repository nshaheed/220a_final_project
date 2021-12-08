

// clock for the rhythm of a class/pattern yeilding thing.
class Phase {
    1::second => dur speed;
    1.0 => float multi; // how fast it is relative to speed
    
    Impulse i => dac;
    
    fun void init(dur spd, float mult) {
        spd => speed;
        mult => multi;
    }
    
    // get how long before the next attack
    fun dur nextEvent() {
        // <<< multi >>>;
        return speed * multi;
    }
    
    fun void execute() {
        0.25 => i.next;
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
    0.25::second => dur speed;
    
    Phase phase1;
    speed => phase1.speed;
    
    Phase phase2;
    speed => phase2.speed;
    1.05 => phase2.multi;
    
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
    
    fun void execute() {
        spork~ clock.execute();
        
        score[0] @=> ScoreEvent currEvent;
        0 => int idx;
        
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
    0.3 => float gain;
    1 => int power;
    
    dur tempo;
    
    SinOsc s1 => Envelope e => Gain g => dac;
    SinOsc s2 => e;
            
    gain => g.gain;
        
    fun void execute() {
        1.0::second / tempo => float diff;
        freq => s1.freq;
        freq-diff => s2.freq;
                
        setEnv();
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

Scheduler s;
Phaser p @=> s.clock;


ScoreEvent rest;
Rest r @=> rest.inst;
5::second => rest.d;

GlobalBeat beat1;

[
rest
, beat(beat1, 220, 1::second, 2000, 8000)
, beat(beat1, 330, 1::second, 2000, 8000)
, beat(beat1, 220, 1::second, 2000, 8000)
, beat(beat1, 440, 1::second, 2000, 8000) 
, beat(beat1, 220, 3::second, 2000, 8000)
, beat(beat1, 330, 1::second, 2000, 8000) 
, beatOff(beat1)
, rest
] @=> s.score;





spork~ s.execute();

100::second => now;