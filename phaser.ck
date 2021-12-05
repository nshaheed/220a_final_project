

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
        return speed * multi;
    }
    
    fun void execute() {
        0.5 => i.next;
    }
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
        phase1.nextEvent() => dur d1;
        phase2.nextEvent() => dur d2;
        
        while(true) {
            // <<< d1, d2 >>>;
            // execute current events
            if (d1 == 0::samp) {
                spork~ phase1.execute();
                phase1.nextEvent() => d1;
            }
            if (d2 == 0::samp) {
                spork~ phase2.execute();
                phase2.nextEvent() => d2;
            }
            
            // update dur values
            min(d1, d2) => dur nextEvent;
            d1 - nextEvent => d1;
            d2 - nextEvent => d2;
            
            // set up things for the next iteration
            nextEvent / 1::samp => tempo.next; // cast dur to float
            nextEvent => now;
        }
    }
}

// get min of two durs
fun dur min(dur a, dur b) {
    if (a < b) {
        return a;
    }
    return b;
}

Phaser p;

spork~ p.execute();

100::second => now;