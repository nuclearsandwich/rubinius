#include "llvm/opcode_iter.hpp"

#include <list>
#include <map>

namespace rubinius {
  namespace jit {
    class ControlFlowWalker {
    public:
      typedef std::list<int> SectionList;

    private:
      VMMethod* vmm_;
      uint8_t* seen_;
      SectionList work_list_;

    public:
      ControlFlowWalker(VMMethod* vmm)
        : vmm_(vmm)
      {
        seen_ = new uint8_t[vmm->total];
        memset(seen_, 0, vmm->total);
      }

      ~ControlFlowWalker() {
        delete[] seen_;
      }

      void add_section(int ip) {
        if(seen_[ip]) return;
        work_list_.push_back(ip);
      }

      template <class EI>
      void run(EI& each) {
        work_list_.push_back(0);

        OpcodeIterator iter(vmm_);

        while(!work_list_.empty()) {
          int ip = work_list_.back();
          work_list_.pop_back();

          iter.switch_to(ip);

          while(seen_[iter.ip()] == 0) {
            seen_[iter.ip()] = 1;

            each.call(iter);

            if(iter.goto_p()) {
              opcode target = iter.goto_target();
              assert(target < vmm_->total);

              add_section(target);

              // Non-terminating goto's stop the current block and queue the code
              // right after them.
              if(!iter.terminator_p() && iter.next_p()) add_section(iter.next_ip());
              break;
            }

            if(iter.terminator_p()) break;

            if(!iter.next_p()) break;
            iter.advance();
          }
        }
      }
    };
  }
}
