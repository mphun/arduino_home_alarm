/*
 Udp NTP Client
 
 Get the time from a Network Time Protocol (NTP) time server
 Demonstrates use of UDP sendPacket and ReceivePacket 
 For more on NTP time servers and the messages needed to communicate with them, 
 see http://en.wikipedia.org/wiki/Network_Time_Protocol
 
 created 4 Sep 2010 
 by Michael Margolis
 modified 17 Sep 2010
 by Tom Igoe
 
 This code is in the public domain.
 */

#include <SPI.h>         
#include <Ethernet.h>
#include <EthernetDNS.h>
#include <Twitter.h>
#include <Udp.h>
#include <Time.h>

// Enter a MAC address and IP address for your controller below.
// The IP address will be dependent on your local network:
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192,168,0,250 };

int switchPin = 2;              // Switch connected to digital pin 2
int lockdetector = 5;          // pin that detects the lock door
int led = 7;
int alertmsg = 0;
int lockmsg = 0;
int alarmcount = 0;
int var=0;
int testalarmcount = 0;
int alarmhour = 12;
//int alarmhour = 0;
int alarmmin = 0;
int alarmday = 4; //wednesday
//int alarmday = 1; //sunday
String alert = String("");
char msg[50];
unsigned long curmillisdoor = 0;
long prevmillis = 0;
long interval = 600000;
long prevmillisled = 0;
long intervalled = 1000;
long prevmillisdoor = 0;
long intervaldoor = 60000;
int ledstate = LOW;



//twitter token. you can get token from http://arduino-tweet.appspot.com/
//this is setup up for the account mshome1 for mike siebenhaar
//Twitter twitter("598199082-Ldr1olFYsVMgzNxSlzl4N2PpL68i43HdEXO6pgF8"); 
//mike phuns account
Twitter twitter("364684807-vuquqVgsTcrx9yO1VpyUZpBo8rkmekMjHsbs7TVg");

unsigned int localPort = 8888;      // local port to listen for UDP packets

byte timeServer[] = { 
  192, 43, 244, 18}; // time.nist.gov NTP server

const int NTP_PACKET_SIZE= 48; // NTP time stamp is in the first 48 bytes of the message

byte packetBuffer[ NTP_PACKET_SIZE]; //buffer to hold incoming and outgoing packets 



void setup() 
{
  pinMode(led, OUTPUT);
  pinMode(switchPin, INPUT);  // sets the digital pin as input to read switch
   pinMode(lockdetector, INPUT);
  // start Ethernet and UDP
  Ethernet.begin(mac,ip);
  Udp.begin(localPort);
  Serial.begin(9600);
  delay(10000);
  Serial.println("starting first test in 10 seconds");
  delay(10000);
  get_time();
  alert = String("Hello tweet is working : ");
  alert = alert + displayTime();
  alert.toCharArray(msg,50);
   tweet(msg);
  Serial.println("test tweet sent");
  Serial.print(alert);
}

void loop()
{
  
  //check if relay have been triggers
  var = digitalRead(switchPin);      // read the pin and save it into var
  if ( var == 1 ) {
    alertmsg = 1;
  }  
    
  //alert light
  if (alertmsg) {
    unsigned long curmillisled = millis();
    if ( curmillisled - prevmillisled > intervalled){ 
        prevmillisled = curmillisled;
        if ( ledstate == LOW){
          ledstate = HIGH;
        }
        else{
          ledstate = LOW;
        }
        digitalWrite(led, ledstate);   // set the LED on
    }
  }
  
  //the if statement helps pause the check of the ntp sever w/o delaying the rest of the code
  unsigned long curmillis = millis();
  if ( curmillis - prevmillis > interval){
    prevmillis = curmillis;
    get_time();
  }

  lockmsg = digitalRead(lockdetector);      // read the pin and save it into var
  if(lockmsg){
    Serial.println("unlock!");
    curmillisdoor = millis();
    Serial.print("timer: ");
    Serial.println(curmillisdoor - prevmillisdoor);
    if ( curmillisdoor - prevmillisdoor > intervaldoor){
      prevmillisdoor = curmillisdoor;
      alert = String("Door is unlock dumbass!!!: ");
      alert = alert + displayTime();
      alert.toCharArray(msg,50);
      tweet(msg);
    }
  }
  else{
     prevmillisdoor = millis(); 
  }
  
  //twitts a weekly test alarm
  alarm(alarmhour,alarmmin,alarmday);
  //twitts when alarm is set off  
  if ( alertmsg && alarmcount == 0 ) {
     alert = String("ALERT!!!: ");
     alert = alert + displayTime();
     alert.toCharArray(msg,50);
     tweet(msg);   
     alarmcount ++;
  }

}

void get_time(){
    sendNTPpacket(timeServer); // send an NTP packet to a time server
  // wait to see if a reply is available
  delay(1000);  
  if ( Udp.available() ) {  
    Udp.readPacket(packetBuffer,NTP_PACKET_SIZE);  // read the packet into the buffer
    //the timestamp starts at byte 40 of the received packet and is four bytes,
    // or two words, long. First, esxtract the two words:

    unsigned long highWord = word(packetBuffer[40], packetBuffer[41]);
    unsigned long lowWord = word(packetBuffer[42], packetBuffer[43]);  
    // combine the four bytes (two words) into a long integer
    // this is NTP time (seconds since Jan 1 1900):
    unsigned long secsSince1900 = highWord << 16 | lowWord;               
    PDT_setTime(secsSince1900);
    Serial.println(displayTime());
  }
  else {
    Serial.println("Failed to get NTP time"); 
  }
}

//convert ntp time to epoch, set PDT time zone and set the time
void PDT_setTime(unsigned long secsSince1900){
    // now convert NTP time into everyday time:
    // Unix time starts on Jan 1 1970. In seconds, that's 2208988800:
    const unsigned long seventyYears = 2208988800UL;     
    // subtract seventy years:
    unsigned long epoch = secsSince1900 - seventyYears;
    // subract 25200 for PDT time
   epoch = epoch - 25200;  
   setTime(epoch);

}

//display PDT date and time
String displayTime(){
    String time;
    time = String("");
   
    time = time + hour() + ":" + minute(); 
    time = time + ":" + second();
    time = time + " " + month();
    time = time + "/" + day();
    time = time + "/" + year();
    time = time + " " + weekday();
    Serial.print("Time\n");     
    Serial.print(time);
    return time;
}

void tweet(char msg[])
{
  Serial.println("connecting ...");
  if (twitter.post(msg))
  {  
    // Specify &Serial to output received response to Serial.
    // If no output is required, you can just omit the argument, e.g.
    // int status = twitter.wait();
    
    int status = twitter.wait(&Serial);
    if (status == 200)
    {
      Serial.println("OK.");
    } 
    else
    {
      Serial.print("failed : code ");
      Serial.println(status);
    }
  } 
  else
  {
   Serial.println("connection failed.");
  }
}

void alarm(int hours, int minutes, int weekdays){
  String alert;
  char msg[50];
  alert = String("Hello test alert: ");
  if ( weekdays != weekday() ){
       testalarmcount = 0;
  }
  if( hours == hour() && minutes == minute() && weekdays == weekday() && testalarmcount == 0 ){
      alert = alert + displayTime();
      alert.toCharArray(msg,50);
      tweet(msg);
      Serial.print(alert);
      testalarmcount = 1;
      
      //delay(60000);  dont need it becuz od the testalarmcount?
  }
}

// send an NTP request to the time server at the given address 
unsigned long sendNTPpacket(byte *address)
{
  // set all bytes in the buffer to 0
  memset(packetBuffer, 0, NTP_PACKET_SIZE); 
  // Initialize values needed to form NTP request
  // (see URL above for details on the packets)
  packetBuffer[0] = 0b11100011;   // LI, Version, Mode
  packetBuffer[1] = 0;     // Stratum, or type of clock
  packetBuffer[2] = 6;     // Polling Interval
  packetBuffer[3] = 0xEC;  // Peer Clock Precision
  // 8 bytes of zero for Root Delay & Root Dispersion
  packetBuffer[12]  = 49; 
  packetBuffer[13]  = 0x4E;
  packetBuffer[14]  = 49;
  packetBuffer[15]  = 52;

  // all NTP fields have been given values, now
  // you can send a packet requesting a timestamp:                 
  Udp.sendPacket( packetBuffer,NTP_PACKET_SIZE,  address, 123); //NTP requests are to port 123
}

