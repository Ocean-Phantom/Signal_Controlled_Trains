# Signal Controlled Trains

Send trains to stations receiving signals that match the train's cargo, or use signals to send a train to pickup cargo. Includes an option to automatically add refuelling stops to train schedules.

## This mod does not work with disabled stops; Use Train Limits instead.

Signal Controlled Trains (SCT) is based on the premise that trains already have cargo and just need to be routed to the correct stop. SCT does not control the full train schedule; it only inserts a new station (+ a temporary stop), when an order is made, and removes it once done. By default, SCT will copy the conditions of the station currently in the insertion position use it for the inserted station as well. The insertion position can be altered using signals.
 
There are three types of routing the mod can perform: First is a delivery, where trains have cargo, and are routed to a stop with the skip signal receiving negative signals for that cargo. Second is a pickup, where are trains are given an 'imaginary' cargo, and seek out station receiving the depot signal together with positive signals for that cargo. (I would have called it virtual cargo, but a friend insisted for the sake of a math joke that trains can deliver Complex cargo loads, and internally this is essentially a delivery with the signs flipped.) Last is a refuelling operation, which can be used in place of Train Control Signal's refuel stops if desired. 

Trains will prioritize refueling first, then delivering their current cargo, then picking up additional loads.

SCT uses the Virtual Signals added by Klonan's [Train Control Signals mod (TCS)](https://mods.factorio.com/mod/Train_Control_Signals), together with three of vanilla Factorio's Virtual Signals.

### Depot Signal (TCS) 

Send this signal to station to denote it as a Provider/Supply station. Any train that leaves a station receiving the Depot Signal will be **Registered for Delivery**, unless it contains no cargo (fluid/item). Upon leaving a station, the train cargo is checked, and depending on mod settings, may immediately attempt to deliver its cargo. A train's network is based on the depot signal it received, which must be in the same network as any *Demand Station* (denoted by the skip signal) to deliver to it.

### Refuel Signal (TCS)

Any station with the Refuel Signal in its name will become a refuel stop, independently of receiving any signals. The station still needs to receive a refuel signal to have a network.

Send this signal to any station to check if trains that leave it need refueling. If so, the train is **Registered for Refuelling**, and will seek out a refuel stop in the same network. The refuelling threshold is identical to TCS's. Note that refuelling orders simply have a 5 sec inactivity condition set, rather than copying something from another schedule.

### Skip Signal (TCS)

Send this signal to a station to denote it as Requester/Demand station. 

Trains will prioritize stations based on how many *types* of the train's cargo they accept. Cargo is 'accepted' by a Demand station if the station receives a negative (-) signal of that Cargo equal to or greater than the amount in the train. The more types accepted, the higher the priority. Otherwise, the train will deliver to the closest stop with space available. 

### Info Signal

Send this signal to a station to give trains an 'imaginary' cargo to pickup. Any negative (-) item or fluid signal sent to a stop that also receives the info signal will be assigned to the train's cargo to pickup. They will seek out Supply stops receiving positive (+) signals for this item or fluid in the same network.

As with deliveries, trains will prioritize stations that supply more *types* of accepted cargo, then prioritize them by distance.

**There are no protections for this:**
You can tell a 1-cargo wagon train to pickup 200 million power armor Mk2s if you desire, and it will wait until it finds a station providing that many. Importantly, trains will also *reserve* all the cargo they can, preventing other trains from pathing to that station. 

The only thing that matters is the signal type; trains without cargo wagons will not accept item signals, and trains without fluid wagons will not accept fluid signals.


In addition, any train attempting to path to a station with the *Info Signal in its name* will be forced to return to the previous station in its schedule (this does not stack with multiple stops). This can be useful for repeatedly making trains attempt to deliver when not using polls, but may require use of the Dot Signal at the previous station to control where to insert new schedules.

### Check Signal

Send this signal to a station to activate **Exclusive Delivery Mode** for any train that leaves this stop. In this mode, Trains will only deliver to stations that can accept *all* of its cargo. If the train is attempting to pick up cargo in **Exclusive Delivery Mode**, then it will only pick up from stations that provide all the cargo it is looking for. 

Neither the sign, nor the value of the check signal matters for setting this mode.

### Dot Signal

Send this signal to a station to override where in the schedule to insert deliveries/pickups/refuelling orders. If no signal is sent, then by default trains will attempt to insert into schedule position which is right after the station it just left. (Ex: Leaving Station #2 in the schedule means the train will insert a new station and conditions into the 3rd slot, copying the wait conditions of the station that was previously 3rd in the list.) 

The sign of the Dot signal does not matter - any negative dot signals will be converted to positives. If the value of the dot signal exceeds the length of the train schedule, it will insert new stations at the end of the list, and will copy the conditions of the first station in the schedule.

Trains do NOT lose the intended position after completing a refueling order unless overridden by another Dot Signal received at that station. They DO however lose it after completing deliveries or pickups.

In addition, any train attempting to path to a station with the *Dot Signal in its name* will be forced to skip over it and path to the next station in its schedule (this does not stack with multiple stops). Functionally equivalent to a stop with Depot Signal in its name when the next stop is not full of trains. This can be useful for setting train wait conditions for deliveries or pickups.

## About Networks: 

Networks are denoted as bitmasks, using the signal value. In other words, the bitwise AND of the two signals must not be equal to 0. This is similar to LTN, Project Cybersyn, and Rail Logistics Dispatcher. 

Trains and Stations can have 3 types of networks each: 
+ Trains that need refueling get a refuel network, and will seek out refuel stations in the same network. Both are identified by the *REFUEL Signal* -Refuel: Refuel signal-> Refuel signal
+ Trains attempting to *deliver* will use the value of the *DEPOT signal* to seek out a Requester/Demand station in the same network, which is determined by the value of the *SKIP signal*. -Delivery: Depot signal -> Skip signal
+ Trains attempting to *pickup* will use the value of the *INFO signal* to seek out a Provider/Supply station in the same network, denoted by the *DEPOT signal* -Pickup: Info signal -> Depot signal