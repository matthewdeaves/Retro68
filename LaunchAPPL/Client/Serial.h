#ifndef SERIAL_H
#define SERIAL_H

#include "LaunchMethod.h"

class Serial : public LaunchMethod
{
public:
    std::string GetName() override { return "serial"; }
    void GetOptions(options_description& desc) override;
    bool CheckOptions(variables_map& options) override;

    std::unique_ptr<Launcher> MakeLauncher(variables_map& options) override;
};

#endif // SERIAL_H
