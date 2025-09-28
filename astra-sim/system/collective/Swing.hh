/******************************************************************************
This source code is licensed under the MIT license found in the
LICENSE file in the root directory of this source tree.
*******************************************************************************/

#ifndef __SWING_HH__
#define __SWING_HH__

#include <list>

#include "astra-sim/system/MemBus.hh"
#include "astra-sim/system/MyPacket.hh"
#include "astra-sim/system/collective/Algorithm.hh"
#include "astra-sim/system/topology/RingTopology.hh"

namespace AstraSim {

class Swing : public Algorithm {
  public:
    Swing(ComType type,
                    int id,
                    RingTopology* ring_topology,
                    uint64_t data_size);
    virtual void run(EventType event, CallData* data);
    RingTopology::Direction specify_direction();
    void process_stream_count();
    void release_packets();
    virtual void process_max_count();
    void reduce();
    bool iteratable();
    virtual int get_non_zero_latency_packets();
    void insert_packet(Callable* sender);
    bool ready();
    void exit();
    bool stepReady();

    RingTopology::Direction dimension;
    MemBus::Transmition transmition;
    int zero_latency_packets;
    int non_zero_latency_packets;
    int id;
    int curr_receiver;
    int curr_sender;
    int nodes_in_ring;
    int stream_count;
    int max_count;
    int remained_packets_per_max_count;
    int remained_packets_per_message;
    int parallel_reduce;
    PacketRouting routing;
    InjectionPolicy injection_policy;
    std::list<MyPacket> packets;
    bool toggle;
    long free_packets;
    long total_packets_sent;
    long total_packets_received;
    uint64_t msg_size;
    std::list<MyPacket*> locked_packets;
    bool processed;
    bool send_back;
    bool NPU_to_MA;

    int rank_offset;
    int rho;
    double offset_multiplier;

    static int stepBarrier[1024];
    static std::vector<Swing*> allSwings;
};

}  // namespace AstraSim

#endif /* __SWING_HH__ */
