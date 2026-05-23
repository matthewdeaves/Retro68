#include <Files.h>
#include <string.h>
#include <stdio.h>

static void safe_out(const char *str)
{
    HParamBlockRec hpb;
    short ref;
    unsigned char fn[4];

    memset(&hpb, 0, sizeof(hpb));
    fn[0] = 3; fn[1] = 'o'; fn[2] = 'u'; fn[3] = 't';
    hpb.fileParam.ioNamePtr = (StringPtr)fn;
    hpb.fileParam.ioFVersNum = 0;
    PBHCreateSync(&hpb);

    memset(&hpb, 0, sizeof(hpb));
    hpb.ioParam.ioNamePtr = (StringPtr)fn;
    hpb.fileParam.ioFVersNum = 0;
    hpb.ioParam.ioPermssn = fsRdWrPerm;
    PBHOpenSync(&hpb);
    ref = hpb.ioParam.ioRefNum;

    hpb.ioParam.ioBuffer = (Ptr)str;
    hpb.ioParam.ioReqCount = strlen(str);
    hpb.ioParam.ioPosMode = fsFromLEOF;
    hpb.ioParam.ioPosOffset = 0;
    hpb.ioParam.ioRefNum = ref;
    PBWriteSync((ParmBlkPtr)&hpb);

    hpb.ioParam.ioRefNum = ref;
    PBCloseSync((ParmBlkPtr)&hpb);
    hpb.ioParam.ioNamePtr = NULL;
    hpb.ioParam.ioVRefNum = 0;
    PBFlushVolSync((ParmBlkPtr)&hpb);
}

static void safe_out_num(const char *prefix, long num)
{
    char buf[64];
    int i = 0, j;
    long n = num;
    char digits[12];
    int dlen = 0;

    while (*prefix) buf[i++] = *prefix++;
    if (n < 0) { buf[i++] = '-'; n = -n; }
    if (n == 0) { digits[dlen++] = '0'; }
    while (n > 0) { digits[dlen++] = '0' + (n % 10); n /= 10; }
    for (j = dlen - 1; j >= 0; j--) buf[i++] = digits[j];
    buf[i++] = '\n';
    buf[i] = '\0';
    safe_out(buf);
}

/*
 * Reimplementation of _open_r that uses PBHOpenSync directly
 * instead of HOpenDF → HOpen (which corrupts File Manager state on System 6)
 */
static int my_open(const char *name, int create, int trunc)
{
    HParamBlockRec pb;
    Str255 pname;
    short ref;
    OSErr err;

    /* Convert C string to Pascal string */
    strncpy((char*)&pname[1], name, 255);
    pname[0] = strlen(name);

    if (create)
        HCreate(0, 0, pname, '????', 'TEXT');

    /* Use PBHOpenSync directly with properly zeroed param block
       instead of HOpenDF which corrupts System 6 File Manager */
    memset(&pb, 0, sizeof(pb));
    pb.ioParam.ioNamePtr = (StringPtr)pname;
    pb.ioParam.ioVRefNum = 0;
    pb.fileParam.ioDirID = 0;
    pb.fileParam.ioFVersNum = 0;
    pb.ioParam.ioPermssn = fsRdWrPerm;
    err = PBHOpenSync(&pb);
    ref = pb.ioParam.ioRefNum;

    if (err != 0)
        return -1;

    if (trunc)
        SetEOF(ref, 0);

    return ref;
}

int main(void)
{
    short ref;
    long cnt;
    OSErr err;

    safe_out("START\n");

    /* Open testfile using our fixed open (no HOpenDF) */
    ref = my_open("testfile", 1, 1);
    safe_out_num("REF=", (long)ref);

    if (ref < 0) {
        safe_out("OPENFAIL\n");
        return 1;
    }

    safe_out("FSWRITE\n");
    cnt = 5;
    err = FSWrite(ref, &cnt, "hello");
    safe_out_num("FSWRITE=", (long)err);

    FSClose(ref);
    safe_out("PASS\n");
    return 0;
}
