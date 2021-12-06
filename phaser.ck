

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
            // <<< nextEvent >>>;
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
            
            // set up and execute the ScoreEvent
            clock.tempo.last()::samp => currEvent.i.tempo;
            spork~ currEvent.i.execute();
            
            
            idx++;
            if (idx < score.cap()) {
                score[idx] @=> currEvent;
            }
            
            currEvent.d => now;
        }
    }
}

// individual events that happen in the score
class ScoreEvent {
    Instr i;
    // tempo bounds to execute event
    float tMin;
    float tMax;
    
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
}

class Beat extends Instr {
    440 => float freq;
    0.3 => float gain;
    
    SinOsc s1 => Envelope e => dac;
    SinOsc s2 => e;
    
    
    0 => g.gain;
    
    fun void execute() {
        1.0::second / tempo => float diff;
        freq => s1.freq;
        freq-diff => s2.freq;
        
        gain => e.target;
        
        e.keyOn();
        
        duration => now;
        
        e.keyOff();
    }
}

Scheduler s;
Phaser p @=> s.clock;

ScoreEvent test;
Beat i @=> test.i;
11000 => test.tMin;
12000 => test.tMax;
5::second => test.d;

[test, test, test, test] @=> s.score;





spork~ s.execute();

100::second => now;