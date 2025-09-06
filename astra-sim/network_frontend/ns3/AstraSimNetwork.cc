#include "astra-sim/system/AstraNetworkAPI.hh"
#include "astra-sim/system/Sys.hh"
#include "extern/remote_memory_backend/analytical/AnalyticalRemoteMemory.hh"
#include <json/json.hpp>

#include "entry.h"
#include "ns3/applications-module.h"
#include "ns3/core-module.h"
#include "ns3/csma-module.h"
#include "ns3/event-id.h"  // STyGIANet: For timers in Ethereal
#include "ns3/internet-module.h"
#include "ns3/network-module.h"
#include <execinfo.h>
#include <fstream>
#include <iostream>
#include <queue>
#include <stdio.h>
#include <string>
#include <thread>
#include <unistd.h>
#include <vector>
#include "astra-sim/common/Logging.hh"
#include <tuple>
#include <algorithm>
#include <random>
#include "ns3/random-variable-stream.h"

using namespace std;
using namespace ns3;
using json = nlohmann::json;

class ASTRASimNetwork : public AstraSim::AstraNetworkAPI {
  public:
    ASTRASimNetwork(int rank) : AstraNetworkAPI(rank) {
        lb_mode = appLoadBalancing::UNSPECIFIED;
        numMpRdmaQp = 1;
        failedPathResetTimeOut = 0;  // OFF by default
        randomize = 0; // OFF by default

        t1Links = 0;
        t2Links = 0;
        nTorsPerPod = 0;
        nTors = 0;

        nRanks = 0;
        demandArray.clear();
        m_rand = CreateObject<UniformRandomVariable>();

        flowInWindow[rank] = 0;
    }

    ~ASTRASimNetwork() {
        Simulator::Cancel(batchTimer);
        for (auto& row : demandArray) {
            row.clear();
            row.shrink_to_fit();
        }
        demandArray.clear();
        demandArray.shrink_to_fit();

        for (auto& row : pathMatrix) {
            row.clear();
            row.shrink_to_fit();
        }
        pathMatrix.clear();
        pathMatrix.shrink_to_fit();

        numFailedPaths.clear();
        numFailedPaths.shrink_to_fit();

        send_flow_args.clear();
    }

    BackendType get_backend_type() override {
        return BackendType::NS3;
    }

    bool etherealEnabled() {
        return lb_mode == appLoadBalancing::ETHEREAL;
    }

    void set_n_ranks(int ranks) {
        nRanks = ranks;
    }

    int get_n_ranks() {
        return nRanks;
    }

    void setLinkFailure(uint32_t uplink, uint32_t dst) {
        uint32_t nPerTor = (nRanks / nTors);
        uint32_t dst_tor = dst / nPerTor;
        uint32_t u;
        if (t2Links == 0 || pathMatrix[dst_tor].size() < t2Links) {
            u = uplink & 0x00FF;
        } else {
            u = (uplink & 0x00FF) * nTorsPerPod + ((uint16_t)(uplink)) >> 8;
        }
        // std::cout << u << " " << uplink << " " << dst << " " << pathMatrix[dst_tor].size() << std::endl;
        NS_ASSERT_MSG(u < pathMatrix[dst_tor].size(),
                      "Invalid uplink index");
        if (!pathMatrix[dst_tor][u].IsPending()) {
            numFailedPaths[dst_tor]++;
        }
        pathMatrix[dst_tor][u].Remove();
        pathMatrix[dst_tor][u] = Simulator::Schedule(
            NanoSeconds(failedPathResetTimeOut),
            &ASTRASimNetwork::resetLinkFailure, this, uplink, dst);
    }

    void resetLinkFailure(uint32_t uplink, uint32_t dst) {
        uint32_t nPerTor = (nRanks / nTors);
        uint32_t dst_tor = dst / nPerTor;
        uint32_t u;        
        if (t2Links == 0 || pathMatrix[dst_tor].size() < t2Links) {
            u = uplink & 0x00FF;
        } else {
            u = (uplink & 0x00FF) * nTorsPerPod + ((uint16_t)(uplink)) >> 8;
        }
        NS_ASSERT_MSG(u < pathMatrix[dst_tor].size(),
                      "Invalid uplink index");
        if (numFailedPaths[dst_tor] > 0) {
            numFailedPaths[dst_tor]--;
        }
        pathMatrix[dst_tor][u].Remove();
    }

    void set_topo_params(uint32_t t1l,
                         uint32_t t2l,
                         uint32_t podTors,
                         uint32_t allTors) {
        // Reset if anything was already allocated perhaps due to
        // misconfiguration
        for (auto& row : demandArray) {
            row.clear();
            row.shrink_to_fit();
        }
        demandArray.clear();
        demandArray.shrink_to_fit();

        for (auto& row : pathMatrix) {
            row.clear();
            row.shrink_to_fit();
        }
        pathMatrix.clear();
        pathMatrix.shrink_to_fit();

        numFailedPaths.clear();
        numFailedPaths.shrink_to_fit();

        // Set the new values
        t1Links = t1l;
        t2Links = t2l;
        nTorsPerPod = podTors;
        nTors = allTors;

        // demandArray: Each destination ToR corresponds to a row and each
        // uplink corresponds to a column. This choice of dimensions is because
        // we typically want to iterate per-destination ToR and assign demand to
        // uplinks. pathMatrix indicates failures corresponding to a destination
        // tor (row) on a particular uplink (column).
        demandArray.resize(nTors);
        pathMatrix.resize(nTors);
        for (uint32_t dst_tor = 0; dst_tor < nTors; dst_tor++) {
            uint32_t nPerTor = (nRanks / nTors);
            uint32_t myRackId = rank / nPerTor;

            if ((dst_tor / nTorsPerPod) == (myRackId / nTorsPerPod)) {
                demandArray[dst_tor].resize(t1Links, 0);
                pathMatrix[dst_tor].resize(t1Links, EventId());
            } else {
                demandArray[dst_tor].resize(t2Links, 0);
                pathMatrix[dst_tor].resize(t2Links, EventId());
            }
        }

        numFailedPaths.resize(nTors, 0);
    }
    bool isRackLocal(uint32_t dst) {
        return (dst / (nRanks / nTors)) == (rank / (nRanks / nTors));
    }

    // STyGIANet
    // This vector holds all the send calls issued by the system layer
    // within a time window.
    using SendFlowArgs =
        std::tuple<int, int, uint64_t, void (*)(void*), void*, int>;

    // STyGIANet
    EventId batchTimer;

    int sim_finish() {
        for (auto it = node_to_bytes_sent_map.begin();
             it != node_to_bytes_sent_map.end(); it++) {
            pair<int, int> p = it->first;
            if (p.second == 0) {
                cout << "All data sent from node " << p.first << " is "
                     << it->second << "\n";
            } else {
                cout << "All data received by node " << p.first << " is "
                     << it->second << "\n";
            }
        }
        exit(0);
        return 0;
    }

    double sim_time_resolution() {
        return 0;
    }

    void handleEvent(int dst, int cnt) {}

    AstraSim::timespec_t sim_get_time() {
        AstraSim::timespec_t timeSpec;
        timeSpec.time_res = AstraSim::NS;
        timeSpec.time_val = Simulator::Now().GetNanoSeconds();
        return timeSpec;
    }

    virtual void sim_schedule(AstraSim::timespec_t delta,
                              void (*fun_ptr)(void* fun_arg),
                              void* fun_arg) {
        Simulator::Schedule(NanoSeconds(delta.time_val), fun_ptr, fun_arg);
        return;
    }

    int gcd(int a, int b) {
        if (b == 0) {
            return a;
        }
        return gcd(b, a % b);
    }

    virtual int sim_send(void* buffer,
                         uint64_t message_size,
                         int type,
                         int dst_id,
                         int tag,
                         AstraSim::sim_request* request,
                         void (*msg_handler)(void* fun_arg),
                         void* fun_arg) {
        int src_id = rank;

        // STyGIANet
        if (lb_mode == appLoadBalancing::ETHEREAL) {
            // std::cout << "Ethereal enabled" << std::endl;
            if (!batchTimer.IsPending() && message_size == 0) {
                // Assuming that sys layer would never call send with message
                // size 0. So this is a signal by the timer to send all the
                // flows in the batch.
                if (send_flow_args.size() == 0) {
                    // nothing to send
                    std::cout << "Who scheduled a message with zero size?! How "
                                 "is the vector size zero too?"
                              << std::endl;
                    exit(0);
                } else {
                    // Send all flows in this batch. This is the opportunity to
                    // do something with this batch of flows that go into the
                    // network.

                    // Ethereal

                    // Randomize the destinations to avoid synchronization
                    std::vector<int> newkeys;
                    for (const auto& [dst, flow_vec] : send_flow_args) {
                        newkeys.push_back(dst);
                    }
                    std::random_device rd;
                    std::mt19937 gen(rank);
                    std::shuffle(newkeys.begin(), newkeys.end(), gen);

                    // int window = 1;
                    std::vector<int> keys;
                    if (newkeys.size()) {
                        for (int dst : newkeys){
                            auto& flow_vec = send_flow_args[dst];
                            std::vector<uint32_t> goodPaths;
                            for (uint32_t p = 0; p < pathMatrix[dst].size();
                                 p++) {
                                if (!pathMatrix[dst][p].IsPending()) {
                                    goodPaths.emplace_back(p);
                                }
                            }
                            uint32_t numFlows = flow_vec.size();
                            uint32_t s = goodPaths.size();
                            uint32_t r = numFlows % s;
                            uint32_t g = gcd(r, s);
                            uint64_t numSplit = s / g;
                            uint32_t totalNewFlows = numFlows + r*(numSplit - 1);
                            if (r){
                                std::cout << "something went wrong!!!" << std::endl;
                                exit(1);
                            }
                            if (flowInWindow[rank] + totalNewFlows <= totalWindowFlows) {
                                flowInWindow[rank] += totalNewFlows;
                                keys.push_back(dst);
                            }
                        }
                        // std::cout << "flowInWindow " << flowInWindow[rank] << " rank " << rank << std::endl;
                    }

                    // Load balance
                    for (int dst : keys) {
                        auto& flow_vec = send_flow_args[dst];
                        // Also randomize the destinations within each
                        // destination ToR to avoid synchronization
                        if (randomize){
                            std::shuffle(flow_vec.begin(), flow_vec.end(), gen);
                        }
                        uint32_t numFlows = flow_vec.size();
                        if (numFlows > 0) {
                            std::vector<uint32_t> goodPaths;
                            for (uint32_t p = 0; p < pathMatrix[dst].size();
                                 p++) {
                                if (!pathMatrix[dst][p].IsPending()) {
                                    goodPaths.emplace_back(p);
                                }
                            }
                            if (randomize){
                                std::shuffle(goodPaths.begin(), goodPaths.end(), gen);
                            }
                            NS_ASSERT_MSG(goodPaths.size() ==
                                              pathMatrix[dst].size() -
                                                  numFailedPaths[dst],
                                          "Good paths size mismatch!");
                            uint32_t s = goodPaths.size();
                            uint32_t path = 0;
                            uint32_t r = numFlows % s;
                            // Send these flows as usual
                            for (uint32_t i = 0; i < numFlows - r; i++) {
                                NS_ASSERT_MSG(std::get<2>(flow_vec[i]) ==
                                                  std::get<2>(flow_vec[0]),
                                              "Flow size assumption failed!");
                                // ToDO: add dst_port parameter for source
                                // routing
                                uint16_t t1Path;
                                uint16_t t2Path;
                                if (t2Links == 0 || pathMatrix[dst].size() < t2Links) {
                                    t1Path = path % goodPaths.size();
                                    t1Path = goodPaths[t1Path];
                                    t2Path = 0;
                                } else {
                                    uint16_t coreSwitch =
                                        path % goodPaths.size();
                                    coreSwitch = goodPaths[coreSwitch];
                                    // Assume 1:1 oversubscription
                                    // Each aggregation switch connect to every
                                    // ToR switch in the south direction. With
                                    // 1:1 oversubscription, each aggregation
                                    // switch must connect to the same number of
                                    // core switches in the north direction.
                                    t1Path = coreSwitch / nTorsPerPod;
                                    t2Path = coreSwitch % nTorsPerPod;
                                }
                                uint16_t mask = 0xFF00;
                                uint16_t myPath = ((t2Path << 8) & mask) | (t1Path & 0x00FF);

                                auto flow_tmp = flow_vec[i];
                                auto src_tmp = std::get<0>(flow_tmp);
                                auto dst_tmp = std::get<1>(flow_tmp);
                                auto message_size_tmp = std::get<2>(flow_tmp);
                                auto msg_handler_tmp = std::get<3>(flow_tmp);
                                auto fun_arg_tmp = std::get<4>(flow_tmp);
                                auto tag_tmp = std::get<5>(flow_tmp);
                                // src_id, dst_id, message_size, msg_handler, fun_arg, tag
                                uint32_t delay = randomize? m_rand->GetInteger(0, 50) : 0;
                                Simulator::Schedule(NanoSeconds(delay),
                                    [=]() {
                                        send_flow(src_tmp,
                                                  dst_tmp,
                                                  message_size_tmp,
                                                  msg_handler_tmp,
                                                  fun_arg_tmp,
                                                  tag_tmp, myPath);
                                    });
                                path++;
                            }
                            if (r > 0) {
                                // Split these last few flows in order to
                                // achieve optimal load balancing
                                uint32_t g = gcd(r, s);
                                uint64_t numSplit = s / g;
                                // std::cout << "splitting numFlows = " << r << " numSplit = " << numSplit << " time " << Simulator::Now().GetNanoSeconds() << std::endl;
                                for (uint32_t i = 0; i < r; i++) {
                                    NS_ASSERT_MSG(
                                        std::get<2>(flow_vec[(numFlows - r) + i]) ==
                                            std::get<2>(flow_vec[0]),
                                        "Flow size assumption failed!");
                                    for (int j = 0; j < numSplit; j++) {
                                        uint16_t t1Path;
                                        uint16_t t2Path;
                                        if (t2Links == 0 || pathMatrix[dst].size() < t2Links) {
                                            t1Path = path % goodPaths.size();
                                            t1Path = goodPaths[t1Path];
                                            t2Path = 0;
                                        } else {
                                            uint16_t coreSwitch =
                                                path % goodPaths.size();
                                            coreSwitch = goodPaths[coreSwitch];
                                            // Assume 1:1 oversubscription
                                            // Each aggregation switch connect
                                            // to every ToR switch in the south
                                            // direction. With 1:1
                                            // oversubscription, each
                                            // aggregation switch must connect
                                            // to the same number of core
                                            // switches in the north direction.
                                            t1Path = coreSwitch / nTorsPerPod;
                                            t2Path = coreSwitch % nTorsPerPod;
                                        }
                                        uint16_t mask = 0xFF00;
                                        uint16_t myPath = ((t2Path << 8) & mask) | (t1Path & 0x00FF);

                                        auto flow_tmp = flow_vec[(numFlows - r) + i];
                                        auto src_tmp = std::get<0>(flow_tmp);
                                        auto dst_tmp = std::get<1>(flow_tmp);
                                        uint64_t flowSize = std::get<2>(flow_tmp) / numSplit;
                                        uint64_t residualFlowSize = flowSize + std::get<2>(flow_tmp) % numSplit;
                                        auto msg_handler_tmp = std::get<3>(flow_tmp);
                                        auto fun_arg_tmp = std::get<4>(flow_tmp);
                                        auto tag_tmp = std::get<5>(flow_tmp);
                                        // src_id, dst_id, message_size, msg_handler, fun_arg, tag
                                        uint32_t delay = randomize? m_rand->GetInteger(0, 50) : 0;
                                        if (j == numSplit-1){
                                            Simulator::Schedule(NanoSeconds(delay),
                                                [=]() {
                                                    send_flow(src_tmp,
                                                              dst_tmp,
                                                              residualFlowSize,
                                                              msg_handler_tmp,
                                                              fun_arg_tmp,
                                                              tag_tmp, myPath);
                                                });
                                        }
                                        else{
                                            Simulator::Schedule(NanoSeconds(delay),
                                                [=]() {
                                                    send_flow(src_tmp,
                                                              dst_tmp,
                                                              flowSize,
                                                              msg_handler_tmp,
                                                              fun_arg_tmp,
                                                              tag_tmp, myPath);
                                                });
                                        }
                                        path++;
                                    }
                                }
                            }
                            flow_vec.clear();
                            send_flow_args.erase(dst);
                        }
                    }
                    // clear the batch
                    if (send_flow_args.size()){
                        if (!batchTimer.IsPending()) {
                            batchTimer = Simulator::Schedule(
                                NanoSeconds(100), &ASTRASimNetwork::sim_send, this,
                                nullptr, static_cast<uint64_t>(0), 0, 0, 0, nullptr,
                                nullptr, nullptr);
                        }
                    }
                    else{
                        send_flow_args.clear();
                    }
                }
            } else if (message_size > 0) {
                // ToDO: Find a better way to check rack locality.
                // The following logic is just for simplicilty, it works
                // based on how we generate FatTree topologies currently.
                uint32_t nPerTor = (nRanks / nTors);
                bool rackLocal = ((src_id / nPerTor) == (dst_id / nPerTor));
                if (!rackLocal) {
                    // No timer scheduled yet. This is the first message.
                    // Schedule the timer. Note that we will not send this
                    // message now. We will send it when the timer triggers.
                    // Event is scheduled with dummy values. Specifically,
                    // message_size = 0 to identify the trigger.
                    if (!batchTimer.IsPending()) {
                        batchTimer = Simulator::Schedule(
                            NanoSeconds(100), &ASTRASimNetwork::sim_send, this,
                            nullptr, static_cast<uint64_t>(0), 0, 0, 0, nullptr,
                            nullptr, nullptr);
                    }
                    // Add the flow to the batch.
                    send_flow_args[dst_id / nPerTor].emplace_back(
                        src_id, dst_id, message_size, msg_handler, fun_arg,
                        tag);
                } else {
                    // Rack Local flows can be sent without load balancing.
                    auto src_tmp = src_id;
                    auto dst_tmp = dst_id;
                    auto message_size_tmp = message_size;
                    auto msg_handler_tmp = msg_handler;
                    auto fun_arg_tmp = fun_arg;
                    auto tag_tmp = tag;
                    uint32_t delay = randomize? m_rand->GetInteger(0, 50) : 0;
                    // flowInWindow[src_id]++;
                    if (flowInWindow[src_id]+1 <= totalWindowFlows){
                        flowInWindow[src_id]++;
                        Simulator::Schedule(NanoSeconds(delay),
                            [=]() { send_flow(src_tmp, dst_tmp, message_size_tmp, msg_handler_tmp, fun_arg_tmp, tag_tmp); });
                        // send_flow(src_id, dst_id, message_size, msg_handler, fun_arg, tag);
                    }
                    else{
                        Simulator::Schedule(
                            NanoSeconds(100), &ASTRASimNetwork::sim_send, this,
                            buffer, message_size, type, dst_id, tag, request,
                            msg_handler, fun_arg);
                    }
                }
            } else {
                std::cout << "Error in sim_send" << std::endl;
                exit(0);
            }
        } else if (lb_mode == appLoadBalancing::MP_RDMA) {
            // std::cout << "MpRDMA enabled" << std::endl;
            for (uint32_t split = 0; split < numMpRdmaQp - 1; split++) {
                send_flow(src_id, dst_id, message_size / numMpRdmaQp,
                          msg_handler, fun_arg, tag);
            }
            send_flow(src_id, dst_id,
                      message_size / numMpRdmaQp + message_size % numMpRdmaQp,
                      msg_handler, fun_arg, tag);
        } else {
            if (message_size > 0){
                // ToDO: Find a better way to check rack locality.
                // The following logic is just for simplicilty, it works
                // based on how we generate FatTree topologies currently.
                uint32_t nPerTor = (nRanks / nTors);
                bool rackLocal = ((src_id / nPerTor) == (dst_id / nPerTor));
                if (!rackLocal) {
                    // No timer scheduled yet. This is the first message.
                    // Schedule the timer. Note that we will not send this
                    // message now. We will send it when the timer triggers.
                    // Event is scheduled with dummy values. Specifically,
                    // message_size = 0 to identify the trigger.
                    if (!batchTimer.IsPending()) {
                        batchTimer = Simulator::Schedule(
                            NanoSeconds(100), &ASTRASimNetwork::sim_send, this,
                            nullptr, static_cast<uint64_t>(0), 0, 0, 0, nullptr,
                            nullptr, nullptr);
                    }
                    // Add the flow to the batch.
                    send_flow_args[dst_id / nPerTor].emplace_back(
                        src_id, dst_id, message_size, msg_handler, fun_arg,
                        tag);
                } else {
                    // Rack Local flows can be sent without load balancing.
                    auto src_tmp = src_id;
                    auto dst_tmp = dst_id;
                    auto message_size_tmp = message_size;
                    auto msg_handler_tmp = msg_handler;
                    auto fun_arg_tmp = fun_arg;
                    auto tag_tmp = tag;
                    uint32_t delay = randomize? m_rand->GetInteger(0, 50) : 0;
                    // flowInWindow[src_id]++;
                    if (flowInWindow[src_id]+1 <= totalWindowFlows){
                        flowInWindow[src_id]++;
                        Simulator::Schedule(NanoSeconds(delay),
                            [=]() { send_flow(src_tmp, dst_tmp, message_size_tmp, msg_handler_tmp, fun_arg_tmp, tag_tmp); });
                        // send_flow(src_id, dst_id, message_size, msg_handler, fun_arg, tag);
                    }
                    else{
                        Simulator::Schedule(
                            NanoSeconds(100), &ASTRASimNetwork::sim_send, this,
                            buffer, message_size, type, dst_id, tag, request,
                            msg_handler, fun_arg);
                    }
                }
            }
            else if (!batchTimer.IsPending() && message_size == 0){
                std::vector<int> newkeys;
                for (const auto& [dst, flow_vec] : send_flow_args) {
                    newkeys.push_back(dst);
                }
                std::random_device rd;
                std::mt19937 gen(rank);
                std::shuffle(newkeys.begin(), newkeys.end(), gen);

                // int window = 1;
                std::vector<int> keys;
                if (newkeys.size()) {
                    for (int dst : newkeys){
                        auto& flow_vec = send_flow_args[dst];
                        if (flowInWindow[rank] + flow_vec.size() <= totalWindowFlows) {
                            flowInWindow[rank] += flow_vec.size();
                            keys.push_back(dst);
                        }
                    }
                    // std::cout << "flowInWindow " << flowInWindow[rank] << " rank " << rank << std::endl;
                }
                for (int dst : keys) {
                    auto& flow_vec = send_flow_args[dst];
                    // Also randomize the destinations within each
                    // destination ToR to avoid synchronization
                    if (randomize){
                        std::shuffle(flow_vec.begin(), flow_vec.end(), gen);
                    }
                    uint32_t numFlows = flow_vec.size();
                    if (numFlows > 0) {
                        // Send these flows as usual
                        for (uint32_t i = 0; i < numFlows; i++) {
                            auto flow_tmp = flow_vec[i];
                            auto src_tmp = std::get<0>(flow_tmp);
                            auto dst_tmp = std::get<1>(flow_tmp);
                            auto message_size_tmp = std::get<2>(flow_tmp);
                            auto msg_handler_tmp = std::get<3>(flow_tmp);
                            auto fun_arg_tmp = std::get<4>(flow_tmp);
                            auto tag_tmp = std::get<5>(flow_tmp);
                            // src_id, dst_id, message_size, msg_handler, fun_arg, tag
                            uint32_t delay = randomize? m_rand->GetInteger(0, 50) : 0;
                            Simulator::Schedule(NanoSeconds(delay),
                                [=]() {
                                    send_flow(src_tmp,
                                              dst_tmp,
                                              message_size_tmp,
                                              msg_handler_tmp,
                                              fun_arg_tmp,
                                              tag_tmp);
                                });
                        }
                        flow_vec.clear();
                        send_flow_args.erase(dst);
                    }
                }
                // clear the batch
                if (send_flow_args.size()){
                    if (!batchTimer.IsPending()) {
                        batchTimer = Simulator::Schedule(
                            NanoSeconds(100), &ASTRASimNetwork::sim_send, this,
                            nullptr, static_cast<uint64_t>(0), 0, 0, 0, nullptr,
                            nullptr, nullptr);
                    }
                }
                else{
                    send_flow_args.clear();
                }

            }
            else {
                std::cout << "Error in sim_send" << std::endl;
                exit(0);
            }
        }
        return 0;
    }

    virtual int sim_recv(void* buffer,
                         uint64_t message_size,
                         int type,
                         int src_id,
                         int tag,
                         AstraSim::sim_request* request,
                         void (*msg_handler)(void* fun_arg),
                         void* fun_arg) {
        int dst_id = rank;
        MsgEvent recv_event =
            MsgEvent(src_id, dst_id, 1, message_size, fun_arg, msg_handler);
        MsgEventKey recv_event_key =
            make_pair(tag, make_pair(recv_event.src_id, recv_event.dst_id));

        if (received_msg_standby_hash.find(recv_event_key) !=
            received_msg_standby_hash.end()) {
            // 1) ns3 has already received some message before sim_recv is
            // called.
            int received_msg_bytes = received_msg_standby_hash[recv_event_key];
            if (received_msg_bytes == message_size) {
                // 1-1) The received message size is same as what we expect.
                // Exit.
                received_msg_standby_hash.erase(recv_event_key);
                recv_event.callHandler();
            } else if (received_msg_bytes > message_size) {
                // 1-2) The node received more than expected.
                // Do trigger the callback handler for this message, but
                // wait for Sys layer to call sim_recv for more messages.
                received_msg_standby_hash[recv_event_key] =
                    received_msg_bytes - message_size;
                recv_event.callHandler();
            } else {
                // 1-3) The node received less than what we expected.
                // Reduce the number of bytes we are waiting to receive.
                received_msg_standby_hash.erase(recv_event_key);
                recv_event.remaining_msg_bytes -= received_msg_bytes;
                sim_recv_waiting_hash[recv_event_key] = recv_event;
            }
        } else {
            // 2) ns3 has not yet received anything.
            if (sim_recv_waiting_hash.find(recv_event_key) ==
                sim_recv_waiting_hash.end()) {
                // 2-1) We have not been expecting anything.
                sim_recv_waiting_hash[recv_event_key] = recv_event;
            } else {
                // 2-2) We have already been expecting something.
                // Increment the number of bytes we are waiting to receive.
                int expecting_msg_bytes =
                    sim_recv_waiting_hash[recv_event_key].remaining_msg_bytes;
                recv_event.remaining_msg_bytes += expecting_msg_bytes;
                sim_recv_waiting_hash[recv_event_key] = recv_event;
            }
        }
        return 0;
    }

    void setWindow(uint32_t windowSizeEthereal){
        totalWindowFlows = windowSizeEthereal;
    }

  private:
    // This 2D array has each row corresponding to a destination ToR and
    // each column corresponding to an uplink. The value at each cell is the
    // demand assigned to an uplink and the destination ToR switch of the
    // demand. Note: This is all a local perspective at each end-host.
    std::vector<std::vector<uint64_t>> demandArray;

    std::vector<std::vector<EventId>> pathMatrix;

    std::vector<uint32_t> numFailedPaths;

    // Topology variables are interpreted as follows.

    // For 2-tier leaf-spine topology: t1Links = number of spine switches,
    // t2Links = 0, nTorsPerPod = nTors = total number of ToR switches.

    // For 3-tier FatTree topology: t1Links = number of uplinks of a ToR switch,
    // t2Links = number of uplinks of an aggregation switch. nTorsPerPod =
    // number of ToR switches in a single pod. nTors = total number of ToR
    // switches.

    // We assume no oversubscription between tor/agg and agg/core layers.
    uint32_t t1Links;
    uint32_t t2Links;
    uint32_t nTorsPerPod;
    uint32_t nTors;

    // For each destination, we maintain a vector of send calls.
    std::unordered_map<int, std::vector<SendFlowArgs>> send_flow_args;

    int nRanks;

    Ptr<UniformRandomVariable> m_rand;

    uint32_t totalWindowFlows;
};

// Command line arguments and default values.
string workload_configuration;
string system_configuration;
string network_configuration;
string memory_configuration;
string comm_group_configuration = "empty";
string logical_topology_configuration;
string logging_configuration = "empty";
string optical_routing_configuration = "empty";
int num_queues_per_dim = 1;
double comm_scale = 1;
double comp_scale = 1;
double injection_scale = 1;
bool rendezvous_protocol = false;
auto logical_dims = vector<int>();
int num_npus = 1;
auto queues_per_dim = vector<int>();
uint32_t qpwindowSize = 1024;


// TODO: Migrate to yaml
void read_logical_topo_config(string network_configuration,
                              vector<int>& logical_dims) {
    ifstream inFile;
    inFile.open(network_configuration);
    if (!inFile) {
        cerr << "Unable to open file: " << network_configuration << endl;
        exit(1);
    }

    // Find the size of each dimension.
    json j;
    inFile >> j;
    if (j.contains("logical-dims")) {
        vector<string> logical_dims_str_vec = j["logical-dims"];
        for (auto logical_dims_str : logical_dims_str_vec) {
            logical_dims.push_back(stoi(logical_dims_str));
        }
    }

    // Find the number of all npus.
    stringstream dimstr;
    for (auto num_npus_per_dim : logical_dims) {
        num_npus *= num_npus_per_dim;
        dimstr << num_npus_per_dim << ",";
    }
    cout << "There are " << num_npus << " npus: " << dimstr.str() << "\n";

    queues_per_dim = vector<int>(logical_dims.size(), num_queues_per_dim);

    inFile.close();
}

// Read command line arguments.
void parse_args(int argc, char* argv[]) {
    CommandLine cmd;
    cmd.AddValue("workload-configuration", "Workload configuration file.",
                 workload_configuration);
    cmd.AddValue("system-configuration", "System configuration file",
                 system_configuration);
    cmd.AddValue("network-configuration", "Network configuration file",
                 network_configuration);
    cmd.AddValue("remote-memory-configuration", "Memory configuration file",
                 memory_configuration);
    cmd.AddValue("comm-group-configuration",
                 "Communicator group configuration file",
                 comm_group_configuration);
    cmd.AddValue("logical-topology-configuration",
                 "Logical topology configuration file",
                 logical_topology_configuration);
    cmd.AddValue("logging-configuration", "Logging configuration file",
                 logging_configuration);

    cmd.AddValue("num-queues-per-dim", "Number of queues per each dimension",
                 num_queues_per_dim);
    cmd.AddValue("comm-scale", "Communication scale", comm_scale);
    cmd.AddValue("comp-scale", "Compute scale", comp_scale);
    cmd.AddValue("injection-scale", "Injection scale", injection_scale);
    cmd.AddValue("rendezvous-protocol", "Whether to enable rendezvous protocol",
                 rendezvous_protocol);
    cmd.AddValue("linkFailure", "whether to simulate link failure, 1=Failure, 0=normal", link_failure);

    cmd.AddValue("qpwindowSize", "Window size for number of QPs",
                 qpwindowSize);
    cmd.AddValue("optical-routing-configuration", "Optical routing config file",
                 optical_routing_configuration);

    cmd.Parse(argc, argv);
}

int main(int argc, char* argv[]) {
    LogComponentEnable("OnOffApplication", LOG_LEVEL_INFO);
    LogComponentEnable("PacketSink", LOG_LEVEL_INFO);

    cout << "ASTRA-sim + NS3" << endl;

    // Read network config and find logical dims.
    parse_args(argc, argv);
    AstraSim::LoggerFactory::init(logging_configuration);
    read_logical_topo_config(logical_topology_configuration, logical_dims);
    if (optical_routing_configuration != "empty") {
        if (auto ok = setup_optical_routing(optical_routing_configuration); ok == -1) {
            std::cerr << "Fail to setup optical routing." << std::endl;
            return -1;
        }
    }
    // Setup network & System layer.
    vector<ASTRASimNetwork*> networks(num_npus, nullptr);
    vector<AstraSim::Sys*> systems(num_npus, nullptr);
    Analytical::AnalyticalRemoteMemory* mem =
        new Analytical::AnalyticalRemoteMemory(memory_configuration);

    for (int npu_id = 0; npu_id < num_npus; npu_id++) {
        networks[npu_id] = new ASTRASimNetwork(npu_id);
        systems[npu_id] = new AstraSim::Sys(
            npu_id, workload_configuration, comm_group_configuration,
            system_configuration, mem, networks[npu_id], logical_dims,
            queues_per_dim, injection_scale, comm_scale, rendezvous_protocol);
        systems[npu_id]->comp_scale = comp_scale;

        // STyGIANet
        // if (networks[npu_id]->etherealEnabled()) {
            networks[npu_id]->set_n_ranks(num_npus);
            networks[npu_id]->setWindow(qpwindowSize);
        // }
    }
    std::cout << "System Initialized!" << std::endl;
    
    // Initialize ns3 simulation.
    if (auto ok = setup_ns3_simulation(network_configuration); ok == -1) {
        std::cerr << "Fail to setup ns3 simulation." << std::endl;
        return -1;
    }

    for (int i = 0; i < num_npus; i++) {
        // STyGIANet
        // Set topology parameters
        // NS_ASSERT_MSG(t1l > 0, "Number of t1 uplinks is not set! This "
        //                        "should be set in the topology file.");
        NS_ASSERT_MSG(podTors > 0, "Number of ToRs is not set! This should "
                                   "be set in the topology file.");
        NS_ASSERT_MSG(allTors > 0, "Number of ToRs is not set! This should "
                                   "be set in the topology file.");
        NS_ASSERT_MSG(networks[i]->get_n_ranks() > 0,
                      "ranks = 0; Number of ranks not set!");
        networks[i]->set_topo_params(t1l, t2l, podTors, allTors);
        n.Get(i)
            ->GetObject<RdmaDriver>()
            ->m_rdma->TraceConnectWithoutContext(
                "linkFailure",
                MakeCallback(&ASTRASimNetwork::setLinkFailure,
                             networks[i]));
        n.Get(i)
            ->GetObject<RdmaDriver>()
            ->m_rdma->TraceConnectWithoutContext(
                "resetLinkFailure",
                MakeCallback(&ASTRASimNetwork::resetLinkFailure,
                             networks[i]));
        // Tell workload layer to schedule first events.
        systems[i]->workload->fire();
    }

    // Run the simulation by triggering the ns3 event queue.
    Simulator::Run();
    Simulator::Stop(Seconds(2000000000));
    Simulator::Destroy();
    std::cout << "Simulation finished!" << std::endl;
    return 0;
}
