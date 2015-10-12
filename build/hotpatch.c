#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BLOCKSIZE 1024
#define HEADMARKER "x<--["
#define TAILMARKER "]--"
#define HEADSIZE (sizeof HEADMARKER - 1)
#define TAILSIZE (sizeof TAILMARKER - 1)

#define check(COND) (void)( \
    !(COND) && (fputs("FAIL: " #COND "\n", stderr), exit(EXIT_FAILURE), 1))

static void patch(FILE *file, long offset, long length, const char *patchpath)
{
    static char block[BLOCKSIZE];
    FILE *patchfile;
    size_t count;
    long pos, goal;

    printf("%8lu..%-8lu %s\n", offset, offset + length, patchpath);

    check((patchfile = fopen(patchpath, "rb")));
    check(fseek(file, offset, SEEK_SET) == 0);
    while((count = fread(block, 1, sizeof block, patchfile)))
        check(fwrite(block, count, 1, file));

    check(!ferror(patchfile));
    fclose(patchfile);

    check(fflush(file) == 0);
/*    check(fseek(file, 0, SEEK_CUR) == 0);*/

    check((pos = ftell(file)) >= 0);
    goal = offset + length;
    if(pos != goal) {
        fprintf(stderr,"PANIC: file corrupted\n"
                       "       reached pos %lu instead of %lu\n", pos, goal);
        exit(EXIT_FAILURE);
    }
}

static long parse_string(char *start, const char *end) {
    char *p, *endp;
    long value;

    for(p = start; p < end; ++p)
        if(*p == '|') goto OK;

    goto FAIL;

OK:
    *p++ = 0;
    value = strtol(p, &endp, 10);
    if(endp == end && 0 <= value && value < LONG_MAX)
        return value;

FAIL:
    fprintf(stderr, "failed to parse `%.*s`\n", (int)(end - start), start);
    return -1;
}

int main(int argc, char *argv[])
{
    char **ap;
    FILE *file;
    long size;
    char *block;
    size_t block_size, count;

    (void)argc;

    check((block = malloc(BLOCKSIZE)));
    block_size = BLOCKSIZE;

    for(ap = argv + 1; *ap; ++ap) {
        check((file = fopen(*ap, "rb+")));
        check(fseek(file, 0, SEEK_END) == 0);
        check((size = ftell(file)) >= 0);
        check(fseek(file, 0, SEEK_SET) == 0);

        printf("patching %s\n", *ap);

        while((count = fread(block, 1, BLOCKSIZE, file))) {
            size_t i, j;
            long pos;

            check((pos = ftell(file)) >= 0);
            pos -= count;

            for(i = 0; i < count; ++i) {
                size_t mark, start;

                if(block[i] != HEADMARKER[0])
                    continue;

                if(count - i < BLOCKSIZE) {
                    check((block = realloc(block, count + BLOCKSIZE)));
                    count += fread(block + count, 1, BLOCKSIZE, file);
                }

                if(count - i < HEADSIZE)
                    goto NEXT;

                if(strncmp(block + i, HEADMARKER, HEADSIZE) != 0)
                    continue;

                mark = i;
                start = i + HEADSIZE;

                for(j = start; j < count; ++j) {
                    long patchsize;

                    if(block[j] != TAILMARKER[0])
                        continue;

                    if(count - j < BLOCKSIZE) {
                        check((block = realloc(block, count + BLOCKSIZE)));
                        count += fread(block + count, 1, BLOCKSIZE, file);
                    }

                    if(count - j < TAILSIZE)
                        goto NEXT;

                    if(strncmp(block + j, TAILMARKER,
                            TAILSIZE) != 0)
                        continue;

                    if((patchsize = parse_string(block + start, block + j)) > 0)
                        patch(file, pos + (long)mark, patchsize, block + start);

                    i = j + TAILSIZE;
                    break;
                }
            }
        }

    NEXT:
        check(!ferror(file));
        fclose(file);
    }

    puts("done.");
    return 0;
}

