

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
        1.0 => i.next;
    }
}

Phase p;
p.init(0.5::second, 0.5);

while (true) {
    p.execute() => 
    p.nextEvent => now;
}