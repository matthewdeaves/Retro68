#include "SharedFile.h"
#include "StreamBasedLauncher.h"
#include "Utilities.h"
#include "Stream.h"
#include "ServerProtocol.h"
#include <chrono>
#include <iostream>
#include <boost/filesystem.hpp>
#include <boost/filesystem/fstream.hpp>

namespace fs = boost::filesystem;
namespace po = boost::program_options;
using namespace std::literals::chrono_literals;

namespace {

class SharedFileStream : public WaitableStream
{
    static const long kReadBufferSize = 4096;
    uint8_t readBuffer[kReadBufferSize];
    fs::path shared_directory;
public:

    void write(const void* p, size_t n) override;

    void wait() override;

    explicit SharedFileStream(po::variables_map &options);
    ~SharedFileStream() override;
};

class SharedFileLauncher : public StreamBasedLauncher
{
    SharedFileStream stream;
public:
    explicit SharedFileLauncher(po::variables_map& options);
};

// cppcheck-suppress uninitMemberVar
SharedFileStream::SharedFileStream(po::variables_map &options)
    : shared_directory(options["shared-directory"].as<std::string>())
{
}

SharedFileStream::~SharedFileStream()
{
}

void SharedFileStream::write(const void* p, size_t n)
{
    if(n == 0)
        return;
    
    {
        fs::ofstream out(shared_directory / "in_channel_1", std::ios::binary);
        out.write((const char*)p, n);
    }

    fs::rename(shared_directory / "in_channel_1", shared_directory / "in_channel");
    
    do
    {
        usleep(100000);
    } while(fs::exists(shared_directory / "in_channel"));
}

void SharedFileStream::wait()
{
    usleep(100000);
    if(fs::exists(shared_directory / "out_channel"))
    {
        {
            fs::ifstream in(shared_directory / "out_channel");

            while(in.read((char*)readBuffer, sizeof(readBuffer)), in.gcount() > 0)
                notifyReceive(readBuffer, in.gcount());
        }
        fs::remove(shared_directory / "out_channel");
    }
}

SharedFileLauncher::SharedFileLauncher(po::variables_map &options)
    : StreamBasedLauncher(options), stream(options)
{
    SetupStream(&stream);
}

} // anonymous namespace

void SharedFile::GetOptions(options_description &desc)
{
    desc.add_options()
        ("shared-directory", po::value<std::string>(), "Path to a directory shared with the old mac")
        ;
}

bool SharedFile::CheckOptions(variables_map &options)
{
    return options.count("shared-directory") != 0;
}

std::unique_ptr<Launcher> SharedFile::MakeLauncher(variables_map &options)
{
    return std::unique_ptr<Launcher>(new SharedFileLauncher(options));
}
