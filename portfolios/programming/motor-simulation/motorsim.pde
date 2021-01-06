/* @pjs preload="disk2.png""; */
void setup() {
  size(1200, 800);
  stroke(#FFFFFF);
  textAlign(CENTER, CENTER);

  forces = new ArrayList<Float>();
  forcespos = new ArrayList<Float>();
  rotorass = new Rotorass(wiremode, velmode);
  //2D ForceVector composed of pointcharge objects
  //sz is pixel screen width so i*sz/vnum = pixel position of each point charge
  //each point charge is sent the information on each magnet
  forcevectors = new VectorField(vnum);
  magnets = new CompositeMagnet(magmode);
}


ArrayList<Float> forces;
ArrayList<Float> forcespos;
Rotorass rotorass;
VectorField forcevectors;
CompositeMagnet magnets;

//sz = screen width, vnum = # of pointcharges , sh = 1/2 distance between pointcharges
float sz = 800;
int vnum = 50;
float sh = sz/vnum/2;

//input __ mode and magnet mode
int wiremode = 0;
int magmode = 0;
int velmode = 2;

//save current and last 
float savecurst;
float savecuren;

Buttonass wirebuttons = new Buttonass(1000, 140, 35, 2, wiremode, "Wiring Config");
Buttonass magnetbuttons = new Buttonass(1000, 210, 35, 6, magmode, "Magnet Config");
Buttonass velbuttons = new Buttonass(1000, 280, 35, 5, velmode, "Speed Config");

void draw() {
  clear();
  //draw the vectors
  forcevectors.drawField();
  //draw the magnets
  magnets.drawMagnet();
  //draws the rotor assembly
  rotorass.radraw();

  //draws the buttons
  wirebuttons.drawButtonass();
  magnetbuttons.drawButtonass();
  velbuttons.drawButtonass();
}

void mousePressed() {
  if (wirebuttons.mouseCheck()) {
    wiremode = wirebuttons.nselect;
  } else if (magnetbuttons.mouseCheck()) {
    magmode = magnetbuttons.nselect;
    magnets.updateMode(magmode);
    rotorass.resetRotor();
  } else if (velbuttons.mouseCheck()) {  
    velmode = velbuttons.nselect;
    rotorass.updateVelocity(velmode);
  }
}
class Button {
  int x;
  int y;
  //half the width
  int sz;
  Button(int x, int y, int wdth) {
    this.x = x;
    this.y = y;
    sz = wdth/2;
  }

  void drawButton() {
    rect(x-sz, y-sz, sz*2, sz*2);
  }

  boolean mouseCheck() {
    boolean output;
    if (mouseX > x-sz && mouseX < x+sz && mouseY > y-sz && mouseY < y+sz) {
      output = true;
    } else output = false;
    return(output);
  }
}
class Buttonass {
  int x;
  int y;
  int sz;
  int widt;
  int n;
  int nselect;
  String title;

  Button[] buttons;
  Buttonass(int x, int y, int size, int quantity, int selected, String title) {
    this.x = x;
    this.y = y;
    this.sz = size;
    this.widt = size*(3*quantity+1)/4;
    n=quantity;
    this.title = title;
    this.nselect = selected;

    buttons = new Button[n];
    for (int i = 0; i<n; i++) {
      buttons[i] = new Button(x-widt/2+(3*i+2)*sz/4, y, sz/2);
    }
  }

  void drawButtonass() {
    strokeWeight(2);
    stroke(#000000);
    fill(#FFFFFF);
    rect(x-widt/2, y-sz/2, widt, sz);
    textSize(25);
    text(title, x , y - sz);
    for (int i = 0; i<n; i++) {
      buttons[i].drawButton();
    }
    fill(#7777FF);
    buttons[nselect].drawButton();
  }
  
  boolean mouseCheck() {
    for(int i = 0; i < n; i++) {
      if (buttons[i].mouseCheck()) {
       nselect = i;
       return(true);
      }
    }
    return(false);
  }
}
//class for individual rotor arm
//force calculations are performed at 6 nodes
class Coil {
  //  float vel;
  //x,y unit value position and angle
  float x;
  float y;
  float startang;

  //node dist is width of coil at top/bottom, nodedist2 is distance in center (to account for bulge in amateur winding)
  //nodes[][] contains the radius, xpos, and ypos to each approximation node
  float nodedir;
  float nodedist;
  float nodedist2;
  float[][] nodes;

  //temporary vars for starting loops and holding values
  boolean first ;
  boolean firstloop;
  float force;
  //force component holders
  float forcex;
  float forcey;

  Coil (float startang) {
    this.startang = startang;
    nodedist=50;
    nodedist2 = 75;
    nodes = new float[6][3];
    nodes[0][0] = 230;
    nodes[1][0] = 230;
    nodes[2][0] = 100;
    nodes[3][0] = 100;
    nodes[4][0] = 165;
    nodes[5][0] = 165;

    first = true;
    firstloop = true;
  }



  void rdraw(float cdir, float maxforce) {

    //cw current direction is blue, ccw is red, neither is white
    //draws the structural lines of the rotor
    strokeWeight(5);
    if (cdir<0) {
      fill(#0000FF);
      stroke(#0000FF);
    } else if (cdir>0) {
      fill(#FF0000);
      stroke(#FF0000);
    } else {
      fill(#FFFFFF);
      stroke(#FFFFFF);
    }
    line(nodes[0][0]*x+sz/2, nodes[0][0]*y+sz/2, 50*x+sz/2, 50*y+sz/2);
    line(nodes[0][1], nodes[0][2], nodes[1][1], nodes[1][2]);
    line(nodes[2][1], nodes[2][2], nodes[3][1], nodes[3][2]);
    line(nodes[4][1], nodes[4][2], nodes[5][1], nodes[5][2]);


    //force direction
    stroke(#000000);
    line(150*x+sz/2, 150*y+sz/2, 150*x+sz/2+forcex, 150*y+sz/2+forcey);
    strokeWeight(2);
    fill(#000000);
    ellipse(150*x+sz/2+forcex, 150*y+sz/2+forcey, 7, 7);

    //draws the approximation nodes on the rotor, colors based on force  
    for (int i = 0; i < 6; i++) {
      colorcalc(cdir, i, maxforce);
      ellipse(nodes[i][1], nodes[i][2], 20, 20);
    }
  }



  //calculates the change in position and force based on angular displacement/direction
  void calculate(float rotation, float cdir) {

    //determines new angle and keeps value between 0 and 2 radians
    rotation+=startang;
    if (rotation>2*PI) {
      rotation = rotation-floor(rotation/(2*PI))*2*PI;
    }

    //converts angular position to coordinate position unit value
    x=cos(rotation);
    y=sin(rotation);

    //performs force calculations based on the position of the coil
    forcex=0;
    forcey=0;
    for (int i = 0; i < 6; i ++) {
      forcex+=forcecalc(cdir, i)[0];
      forcey+=forcecalc(cdir, i)[1];
    }

    force = (-forcex*y+forcey*x)/sqrt(y*y+x*x);
    forces.add(force);
    forcespos.add(rotation);
  }



  //color gradient calculation
  //(radius of node, cdir, node #, scale proportion for gradient
  void colorcalc(float cdir, int n, float scale) {
    forcex=forcecalc(cdir, n)[0];
    forcey=forcecalc(cdir, n)[1];
    force = (-forcex*y+forcey*x)/sqrt(y*y+x*x);
    if (force >= 0) {
      fill(lerpColor(#FFFFFF, #00FF00, force/(scale)));
      //stroke(lerpColor(#FFFFFF, #00FF00, tempforce/20));
    } else {
      fill(lerpColor(#FFFFFF, #FF0000, -force/(scale)));
      //stroke(lerpColor(#FFFFFF, #FF0000, -tempforce/20));
    }
  }


  //force calculations at each node
  float[] forcecalc(float d, int n) {
    //x1,y1 temp holders
    int x1;
    int y1;
    float l = nodes[n][0];
    float[] forcereturn = new float[2];
    if (n % 2 == 1) {
      nodes[n][1] = l*x+sz/2-nodedist*y/(abs(x)+abs(y));
      nodes[n][2] = l*y+sz/2+nodedist*x/(abs(x)+abs(y));
      x1 = round((nodes[n][1]) * vnum/sz);
      y1 = round((nodes[n][2]) * vnum/sz);
      forcereturn[0]=-d*forcevectors.vectors[x1][y1].vy;
      forcereturn[1]=d*forcevectors.vectors[x1][y1].vx;
    } else {
      nodes[n][1] = l*x+sz/2+nodedist*y/(abs(x)+abs(y));
      nodes[n][2] = l*y+sz/2-nodedist*x/(abs(x)+abs(y));
      x1 = round((nodes[n][1]) * vnum/sz);
      y1 = round((nodes[n][2]) * vnum/sz);
      forcereturn[0]=d*forcevectors.vectors[x1][y1].vy;
      forcereturn[1]=-d*forcevectors.vectors[x1][y1].vx;
    }
    return forcereturn;
  }
}
class CompositeMagnet {
  int mode;
  ArrayList<Magnet> mags;

  CompositeMagnet(int mode) {
    this.mode = mode;
    mags = new ArrayList<Magnet>();
    updateMode(this.mode);
  }


  void drawMagnet() {
    for (int i3 = 0; i3 < mags.size(); i3++) {
      mags.get(i3).drawmag();
    }
  }


  void updateMode(int newmode) {
    mode = newmode;
    magSwitch();
    forcevectors.generateVectors(mags);
  }



  void magSwitch() {
    for (int i = mags.size() - 1; i >= 0; i--) {
      mags.remove(i);
    }

    switch(mode) { 
    case 0: 
      maggen(0, true);
      maggen(PI, false);
      break;
    case 1:
      maggen(-0.32, true);
      maggen(0.32, true);
      maggen(PI-0.32, false);
      maggen(PI+0.32, false);
      break;
    case 2:
      maggen(-PI/4, true);
      maggen(PI/4, true);
      maggen(PI-PI/4, false);
      maggen(PI+PI/4, false);
      break;
    case 3:
      //topleft
      maggen(PI+PI/4+0.2, false); 
      maggen(PI+PI/4-0.2, true);
      //topright
      maggen(-PI/4+0.2, false);
      maggen(-PI/4-0.2, true);
      //bottomright
      maggen(PI/4+0.2, true);
      maggen(PI/4-0.2, false);
      //bottomleft
      maggen(PI-PI/4+0.2, true);
      maggen(PI-PI/4-0.2, false);
      break;
    case 4:
      maggen(0, true);
      maggen(PI, false);
      maggen(-PI/6-0.13, true);
      maggen(PI/6+0.13, true);
      maggen(PI-PI/6-0.13, false);
      maggen(PI+PI/6+0.13, false);
      break;
    case 5:
      maggen(-0.32, true);
      maggen(0.32, true);
      maggen(PI-0.32, false);
      maggen(PI+0.32, false);

      maggen(-0.96, true);
      maggen(0.96, true);
      maggen(PI-0.96, false);
      maggen(PI+0.96, false);
      break;
    }
  }



  void maggen(float ang, boolean pol) {
    PImage img;
    img = loadImage("disk2.png");
    pushMatrix();
    translate(sz/2, sz/2);
    rotate(ang);
    image(img, -800, -800);
    popMatrix();

    for (int i = 0; i < sz; i+=5) {
      for (int i2 = 0; i2 < sz; i2+=5) {

        if (get(i, i2)!=-1) {  
          if (pol) {
            // if (i>sz/2) {
            mags.add(new Magnet(i, i2, -ang, (float)-get(i, i2)/16777216));
          } else {
            mags.add(new Magnet(i, i2, PI-ang, (float)-get(i, i2)/16777216));
          }
        }
      }
    }
  }
}
class ForceVector {
  float posx;
  float posy;
  float mag;
  float dir;
  float vx;
  float vy;
  color c;
  float push;
  ForceVector(float x, float y) {
    posx = x;
    posy = y;
  }
  void addmag(Magnet m) {
    addvect(m.posc);
    addvect(m.negc);
  }

  void addvect(PointCharge c) {
    float R= sqrt(pow(c.posx-posx, 2) +pow(c.posy-posy, 2));
    float newmag = (1/(4*PI))*(1/pow(R, 2))*1000000*c.charge;
    push+=newmag;
    /*
    float dir1 = asin((c.posy-posy)/R)+PI;
     float dir2  = acos((c.posx-posx)/R)+PI;
     vx = vx+newmag*cos(dir2);
     vy = vy+newmag*sin(dir1) ;
     float nvx = newmag*cos(dir2);
     float nvy = newmag*sin(dir1);
     */
    float dir1 = (c.posy-posy)/R;
    float dir2  = (c.posx-posx)/R;
    vx = vx+newmag*dir2;
    vy = vy+newmag*dir1 ;
    float nvx = newmag*dir2;
    float nvy = newmag*dir1;
    if (c.posx <= posx) {
      dir = (atan((vy+nvy)/(vx+nvx)));
    } else {
      dir = (atan((vy+nvy)/(vx+nvx)))+PI;
    }
    mag = sqrt(pow((vx+nvx), 2)+pow((vy+nvy), 2));
  }

  void drawvect() {
    pushMatrix();
    translate(posx+sh, posy+sh);

    if (log(sqrt(vx*vx+vy*vy)+1) < 3) {
      c = lerpColor(#77FF77, #FFB777, (float)log(sqrt(vx*vx+vy*vy)+1)/3);
    } else {
      c = lerpColor(#FFB777, #FF7777, (float)(log(sqrt(vx*vx+vy*vy)+1)-3)/3);
    }

    //  c = lerpColor(#03FF2A,#FF8103,push/10+0.6);
    fill(c);
    rect(-5, -5, sz/vnum, sz/vnum);

    strokeWeight(2);
    stroke(#000000);
    float t = sz/vnum*2/3;
    float x=vx*t/(abs(vx)+abs(vy));
    float y=vy*t/(abs(vx)+abs(vy));
    ellipse(x*0.5, y*0.5, 2, 2);
    ellipse(x*0.7, y*0.7, 0.1, 0.1);
    line(-x/2, -y/2, x/2, y/2);
    noStroke();
    popMatrix();
  }
}
class PointCharge {
float charge;
float posx;
float posy;
PointCharge(float x, float y, float c) {
  charge = c;
  posx = x;
  posy = y;
}
}
//the constructed rotor assembly composed of the coils
class Rotorass {
  //the three coils that compose the assembly
  Coil coil1;
  Coil coil2;
  Coil coil3;
  float coilangle=0;

  //current force, avg force of last run, and avg force overall
  float force;
  float avgforce;
  float avgavgforce;
  float angle;
  float vel;
  float thold;
  float maxforce=1;
  float totforce;
  float loops;
  float lastang = 0;
  float numcalc = 0;
  int mode;
  float pspace;

  //temporary vars for starting loops and holding values
  boolean firstloop;
  float temp;


  Rotorass(int m, float velmode) {
    mode = m;
    switch (mode) {
      case (-1):
      coilangle = 0;
      pspace = 2*PI/3;
      break;
      case (0):
      coilangle = 0;
      pspace = 0.05;
      break;
      case (1):
      coilangle = -PI/6;
      pspace = 0.05;
      break;
      case (2):
      coilangle = -PI/6;
      pspace = 0.2;
      break;
      case (3):
      coilangle = -PI/6;
      pspace = 0.2;
      break;
      case (4):
      coilangle = -PI/6;
      pspace = 3*PI/24;
      break;
      case (5):
      coilangle = -PI/6;
      pspace = 3*PI/24;
      break;
    }
    //sets up each coil with its starting angle
    coil1 = new Coil(coilangle);
    coil2 = new Coil(2*PI/3+coilangle);
    coil3 = new Coil(4*PI/3+coilangle);
    avgforce = 0;
    avgavgforce = 0;
    angle=PI/2;
    thold = 0;
    updateVelocity(velmode);
    // vel = 0;
    firstloop = true;
  }


  void rotorcalc() {
    //thold is the time since displacement was last changed
    thold=(float)millis()-thold;
    //converts ang velocity into ang displacement)  
    angle+=vel*thold/1000;
    if (angle>2*PI) {
      fullloop();
    }
    thold = (float)millis();

    //performs the coil's force calculations based on new angle
    //mode based on the coil's wiring
    if (mode == 0) {
      if (dispcalc(PI/3) == dispcalc(PI) || dispcalc(PI/3) == dispcalc(5*PI/3)) {
        coil1.calculate(angle, dispcalc(PI/3)/3);
      } else {
        coil1.calculate(angle, 2*dispcalc(PI/3)/3);
      } 
      if (dispcalc(PI) == dispcalc(PI/3) || dispcalc(PI) == dispcalc(5*PI/3)) {
        coil2.calculate(angle, dispcalc(3*PI/3)/3);
      } else {
        coil2.calculate(angle, 2*dispcalc(3*PI/3)/3);
      }
      if (dispcalc(5*PI/3) == dispcalc(PI) || dispcalc(5*PI/3) == dispcalc(PI/3)) {
        coil3.calculate(angle, dispcalc(5*PI/3)/3);
      } else {
        coil3.calculate(angle, 2*dispcalc(5*PI/3)/3);
      }
    } else {
      coil1.calculate(angle, dispcalc(PI/3));
      coil2.calculate(angle, dispcalc(PI));
      coil3.calculate(angle, dispcalc(5*PI/3));
    }

    //adds up all of the normal forces and adds them to the total
    force = coil1.force + coil2.force + coil3.force;
    if (firstloop) {
      if (abs(coil1.force)>maxforce) maxforce = abs(coil1.force);
      if (abs(coil2.force)>maxforce) maxforce = abs(coil2.force);
      if (abs(coil3.force)>maxforce) maxforce = abs(coil3.force);
    }
    totforce+=force;
    numcalc++;
  }

  void radraw() {
    rotorcalc();
    fill(#FFFFFF);
    textSize(20);
    text("Force: " + round(force), 1000, 20);
    //text("Max Force: " + (float)round(maxforce), 1000, 60);
    text("Avg Force (last): " + (float)round(avgforce*100)/100, 1000, 320);
    text("Avg Force (total): " + (float)round(avgavgforce*100)/100, 1000, 360);

    //draws the contacts view
    noStroke();
    fill(#FFFFFF);
    rect(820, 420, 360, 360);
    fill(#000000);
    pushMatrix();
    translate(1000, 600);

    angfill(PI/3);
    arc(0, 0, 150, 150, angle+pspace, angle+2*PI/3-pspace);
    angfill(3*PI/3);
    arc(0, 0, 150, 150, angle+2*PI/3+pspace, angle+4*PI/3-pspace);
    angfill(5*PI/3);
    arc(0, 0, 150, 150, angle+4*PI/3+pspace, angle+2*PI-pspace);

    noStroke();
    fill(#FFFFFF);
    ellipse(0, 0, 140, 140);
    if (mode == 3) {
      fill(#0000FF);
      rect(-25, -85, 50, 10);
      fill(#FF0000);
      rect(-25, 75, 50, 10);
    } else {
      fill(#FF0000);
      rect(-85, -25, 10, 50);
      fill(#0000FF);
      rect(75, -25, 10, 50);
    }

    stroke(#000000);
    strokeWeight(30);
    //temp holds current angle of the coils
    temp = angle + coilangle;
    angfill(PI/3);
    line(20*cos(temp), 20*sin(temp), 45*cos(temp), 45*sin(temp));
    angfill(3*PI/3);
    line(20*cos(2*PI/3+temp), 20*sin(2*PI/3+temp), 45*cos(2*PI/3+temp), 45*sin(2*PI/3+temp));
    angfill(5*PI/3);
    line(20*cos(4*PI/3+temp), 20*sin(4*PI/3+temp), 45*cos(4*PI/3+temp), 45*sin(4*PI/3+temp));

    popMatrix();

    //draws the rotor field view
    coil1.rdraw(dispcalc(PI/3), maxforce);
    coil2.rdraw(dispcalc(PI), maxforce);
    coil3.rdraw(dispcalc(5*PI/3), maxforce);
    //converts forces into a gradient value/hue where green is positive and red is negative
    //uses that color to draw the center force measurement lines
    fill(#777777);
    noStroke();
    ellipse(sz/2, sz/2, 100, 100);
    if (forces.size()>1) {
      for (int i = 1; i < forces.size(); i++) {
        if (forces.get(i) >= 0) {
          stroke(lerpColor(#FFFFFF, #00FF00, forces.get(i)/maxforce));
        } else {
          stroke(lerpColor(#FFFFFF, #FF0000, -forces.get(i)/maxforce));
        }
        strokeWeight(1.6*vel+0.9);
        line(sz/2, sz/2, sz/2+cos(forcespos.get(i))*50, sz/2+sin(forcespos.get(i))*50);
      }
    }
    noFill();
    stroke(#000000);
    strokeWeight(5);
    ellipse(sz/2, sz/2, 100, 100);
  }


  //colors rotor red/blue based on current direction as determined by input angle
  void angfill(float inputang) {
    float d = angle+inputang;
    d = d-floor(d/(2*PI))*2*PI;
    switch (mode) {
    case 0:
      if (d > PI-2*PI/6 && d < PI+2*PI/6) {
        fill(#FF0000);
        stroke(#FF0000);
      } else if (d < 2*PI/6 || d > 2*PI-2*PI/6) {
        fill(#0000FF);
        stroke(#0000FF);
      } else if (d<PI) {
        fill(#FF0000);
        stroke(#FF0000);
      } else if (d>PI) {
        fill(#0000FF);
        stroke(#0000FF);
      }
      break;
      case (3):
      if (d>PI/2-PI/3+pspace && d < PI/2-pspace || d>PI/2+pspace && d<PI/2+PI/3-pspace ) {
        fill(#FF0000);
        stroke(#FF0000);
      } else if (d>3*PI/2-PI/3+pspace && d < 3*PI/2-pspace || d>3*PI/2+pspace && d<3*PI/2+PI/3-pspace ) {
        fill(#0000FF);
        stroke(#0000FF);
      } else {
        fill(#000000);
        stroke(#000000);
      }
      break;
      case (-1):
      fill(#FF0000);
      stroke(#FF0000);
      break;
    default:
      if (d>PI-PI/3+pspace && d < PI-pspace || d>PI+pspace && d<PI+PI/3-pspace ) {
        fill(#FF0000);
        stroke(#FF0000);
      } else if (d< PI/3-pspace && d> pspace || d>2*PI-PI/3+pspace && d < 2*PI-pspace) {
        fill(#0000FF);
        stroke(#0000FF);
      } else {
        fill(#000000);
        stroke(#000000);
      }
      break;
    }
  }

  float nome(float n) {
    return(n-floor(n/(2*PI))*2*PI);
  }

  float dispcalc(float inputang) {
    float d = angle+inputang;

    d = nome(d);

    if (mode == 0) {
      if (d>PI-2*PI/6 && d < PI+2*PI/6) {
        return(1);
      } else if (d< 2*PI/6 || d>2*PI-2*PI/6) {
        return(-1);
      } else if (d<PI) {
        return(1);
      } else if (d>PI) {
        return(-1);
      } else {
        return(0);
      }
    } else if (mode == 3) {
      if (d>nome(PI/2-PI/3+pspace) && d < nome(PI/2-pspace) || d>nome(PI/2+pspace) && d<nome(PI/2+PI/3-pspace) ) {
        return(1);
      } else if (d>nome(3*PI/2-PI/3+pspace) && d < nome(3*PI/2-pspace) || d>nome(3*PI/2+pspace) && d<nome(3*PI/2+PI/3-pspace) ) {
        return(-1);
      } else {
        return(0);
      }
    } else if (mode  == -1) {
      return(1);
    } else {
      if (d>PI-PI/3+pspace && d < PI-pspace || d>PI+pspace && d<PI+PI/3-pspace ) {
        return(1);
      } else if (d< PI/3-pspace && d> pspace || d>2*PI-PI/3+pspace && d < 2*PI-pspace) {
        return(-1);
      } else {
        return(0);
      }
    }
  }


  //at the end of a full cycle updates last avg force and overall avgforce and resets angle to between 0 and 2 radians
  void fullloop() {
    if (!firstloop) {
      loops++;
      avgforce = totforce/(numcalc);
      avgavgforce = (avgavgforce*(loops-1)+avgforce)/(loops);
    } else {
      firstloop = false;
    }
    numcalc=0;
    totforce = 0;
    //the current angular displacement of the loop
    angle = angle-floor(angle/(2*PI))*2*PI;
    forces.clear();
    forcespos.clear();
  }


  void resetRotor() {
    fullloop();
    angle = 0;
    avgforce = 0;
    avgavgforce = 0;
    loops = 0;
    maxforce = 1;
    firstloop = true;
  }


  void updateVelocity(float velmode) {
    this.vel=pow(2, velmode) * PI/16;
  }
}
class VectorField {
  int nwidth;
  int nheight;
  int quantity;
  ForceVector[][] vectors;

  VectorField(int quantity) {
    nwidth = 0;
    nheight = 0;
    this.quantity = quantity;
    vectors = new ForceVector[quantity][quantity];
  }



  void drawField() {
    for (int i = 0; i < vnum; i++) {
      for (int i2 = 0; i2 < vnum; i2++) {
        vectors[i][i2].drawvect();
      }
    }
  }


  void generateVectors(ArrayList<Magnet> mags) {
    for (int i = 0; i < quantity; i++) {
      for (int i2 = 0; i2 < quantity; i2++) {
        vectors[i][i2]  = new ForceVector(i*sz/quantity, i2*sz/quantity);
        for (int i3 = 0; i3 < mags.size(); i3++) {
          vectors[i][i2].addmag(mags.get(i3));
        }
      }
    }
    println("update");
  }
}
class Magnet {
  float posx;
  float posy;
  float dir;
  float str;
  PointCharge posc;
  PointCharge negc;
  Magnet(float x, float y, float ang, float s) {
    posx = x;
    posy = y;
    dir = ang;
    str = s*0.1;
    posc = new PointCharge(x+sh*cos(-dir), y+sh*sin(-dir), str);
    negc = new PointCharge(x-sh*cos(-dir), y-sh*sin(-dir), -str);
  }
  void drawmag() {
    int w = 20;
    pushMatrix();
    translate(posx+sh, posy+sh);
    rotate(-dir);
    stroke(#000000);
    strokeWeight(1);
   // noStroke();
    fill(#FA0808);
    rect(0, -w/4, w/2, w/2);
    fill(#0815FA);
    rect(-w/2, -w/4, w/2, w/2);
    fill(#000000);
   noStroke();
    ellipse(0, 0, 3, 3);
    fill(#57D335);
    ellipse(w/2,0,3,3);
    ellipse(-w/2,0,3,3);
    
    popMatrix();
  }
}