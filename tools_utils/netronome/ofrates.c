#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>

typedef struct cmdlist_s {
  const char *cmdpath;
  const char *optargs;
  const char *defbridge;
} cmdlist_t;

cmdlist_t cmdlist[] = {
  { "/opt/netronome/bin/ovs-ofctl", "-O OpenFlow13", "NFE" },
  { "/usr/local/bin/ovs-ofctl", "-O OpenFlow13", "br0" },
  { "/usr/bin/ovs-ofctl", "", "br-int" },
  { NULL, NULL, NULL }
};

const cmdlist_t *
select_ovs_vsctl_cmd ()
{
  cmdlist_t *cp;
  for (cp = &cmdlist[0] ; cp->cmdpath != NULL ; cp++) {
    struct stat fstat;
    int rc = lstat(cp->cmdpath, &fstat);
    if (rc < 0)
      continue;
    if (S_ISREG(fstat.st_mode))
      return cp;
  }
  return NULL;
}

int exec_ovs_vsctl_dump_flows (const cmdlist_t *cp,
  const char *fname, const char *brname)
{
  char cmd[256];
  snprintf(cmd, 254, "%s %s dump-flows %s > %s",
    cp->cmdpath, cp->optargs, brname, fname);
  return system(cmd);
}

typedef struct of_sample_s {
  struct of_sample_s *prev, *next;
  struct timeval tv;
  uint64_t pkt, oct;
  int table;
  int priority;
  int strnext;
  const char *brname;
  const char *filt;
  const char *action;
} of_sample_t;

void of_string_append (of_sample_t *sp,
  const char *str, int maxlen, const char **dpr)
{
  /* Get pointer to available string space */
  char *dp = &((char *) &sp[1])[sp->strnext];
  int len = strlen(str);
  if ((maxlen > 0) && (len > maxlen))
    len = maxlen;
  strncpy(dp, str, len);
  sp->strnext += 1 + len;
  /* Assign Destination Pointer Reference */
  if (dpr != NULL)
    *dpr = dp;
}

static of_sample_t *
find_matching_rule (of_sample_t *hp, of_sample_t *ep)
{
  of_sample_t *sp;
  for (sp = hp->next ; sp != hp ; sp = sp->next) {
    if ((strcmp(sp->filt, ep->filt) == 0) &&
        (sp->priority == ep->priority) &&
        (sp->table == ep->table))
      return sp;
  }
  return NULL;
}

static void
free_list (of_sample_t *hp)
{
  while (hp->next != hp) {
    of_sample_t *fp = hp->next;
    hp->next = fp->next;
    free(fp);
  }
  hp->prev = hp;
}

static inline int
ival_calc (struct timeval tv0, struct timeval tv1)
{
  return
    (tv1.tv_sec  - tv0.tv_sec) * 1000000 +
    (tv1.tv_usec - tv0.tv_usec);
}

static void
print_rule_stats (of_sample_t *hp0, of_sample_t *hp1)
{
  printf("\n\n\n\n\n\n\n\n"
    "        [bytes]         [pkts]    [Mpps]  [Gbps]   "
    "Bridge  Tbl Pri  Action            Rule\n");

  double delta = ((double) ival_calc(hp1->tv, hp0->tv)) / 1e6;
  of_sample_t *ep0;
  for (ep0 = hp0->next ; ep0 != hp0 ; ep0 = ep0->next) {
    of_sample_t *ep1 = find_matching_rule(hp1, ep0);
    if (ep1 == NULL)
      continue;
    double pktrate = (double) (ep0->pkt - ep1->pkt) / 1e6 / delta;
    double bitrate = (double) (ep0->oct - ep1->oct) * 8.0 / 1e9 / delta;
    printf("%15lu %14lu", ep0->oct, ep0->pkt);
    printf("   %7.3f %7.3f", pktrate, bitrate);
    printf("   %-7s %3u %3u  %-16s  %s\n",
      ep0->brname, ep0->table, ep0->priority, ep0->action, ep0->filt);
  }
  printf("\n");
}

static const char *
field_strip (char *str)
{
  char *eqp = strchr(str, '=');
  if (eqp == NULL) return "";
  *eqp = 0;
  str = &eqp[1];
  int sl = strlen(str);
  while ((sl > 0) && (str[sl - 1] == ','))
    str[--sl] = 0;
  return str;
}

static int
read_stat_file (of_sample_t *hp, const char *brname, const char *fname)
{
  FILE *fd = fopen(fname, "r");
  char line[512];
  while (fgets(line, 512, fd) != NULL) {
    if (strncmp(line, " cookie=", 8) == 0) {
      const char *str = line;
      /* Allocate data structure */
      int size = sizeof(of_sample_t) + 2 + strlen(str);
      of_sample_t *sp = (of_sample_t *) malloc(size);
      memset(sp, 0, size);
      /* Set Bridge Name */
      of_string_append(sp, brname, 0, &sp->brname);
      for (;;) {
        char fns[512], as[512]; /* Field name string and argument string */
        while (isspace(*str))
          str++;
        const char *fnp = str;                  /* Field name pointer */
        const char *esp = index(str, '=');      /* Equal-sign pointer */
        const char *asp = &esp[1];              /* Argument field pointer */
        const char *efp;                        /* End-of-field pointer */
        const char *nfp = asp;                  /* Next Field pointer */
        if (esp == NULL)
          break;
        int fn_len = (int) (esp - fnp);
        strncpy(fns, fnp, fn_len);
        fns[fn_len] = 0;
        /* Search to the end of the 'field' */
        while (isgraph(*nfp))
          nfp++;
        /* Step back and eliminate potential commas */
        for (efp = nfp ; efp[-1] == ',' ; efp--)
          ;
        int as_len = (int) (efp - asp);
        const char *p;
        int i;
        for (i = 0, p = &esp[1] ; isgraph(*p) && (*p != ',') ; p++, i++)
          as[i] = *p;
        as[i] = 0;
        //printf("field: -%s-%s-\n", fns, as);
        /* Check for fields one-by-one */
        if (strcmp(fns, "n_packets") == 0) {
          sp->pkt   = strtoul(as, NULL, 0);
        } else
        if (strcmp(fns, "n_bytes") == 0) {
          sp->oct   = strtoul(as, NULL, 0);
        } else
        if (strcmp(fns, "table") == 0) {
          sp->table = strtoul(as, NULL, 0);
        } else
        if (strcmp(fns, "actions") == 0) {
          of_string_append(sp, asp, as_len, &sp->action);
        } else
        if (strcmp(fns, "priority") == 0) {
          sp->priority = strtoul(as, NULL, 0);
          /* This field is treated a little bit differently */
          const char *cfp = index(p, ',');
          if ((cfp == NULL) || (cfp > nfp)) {
            sp->filt = "";
          } else {
            of_string_append(sp, &cfp[1], (int) (efp - cfp), &sp->filt);
          }
        } /* else
        if (strcmp(fns, "in_port") == 0) {
        } */
        str = nfp;
      }
      if ((sp->action == NULL) || (sp->filt == NULL)) {
        free(sp);
        printf("Could not parse: %s\n", line);
        continue;
      }
      // Link-in new entry
      sp->prev = hp->prev;
      sp->next = hp;
      hp->prev->next = sp;
      hp->prev = sp;
    }
  }
  fclose(fd);
}

int main (int argc, char *argv[])
{
  of_sample_t hp[2], *hp0, *hp1, *tp;
  hp0 = hp[0].next = hp[0].prev = &hp[0];
  hp1 = hp[1].next = hp[1].prev = &hp[1];

  const cmdlist_t *cp = select_ovs_vsctl_cmd();

  if (cp == NULL)
    return -1;

  const char *brname = cp->defbridge;

  if (argc == 2)
    brname = argv[1];


  char fname[128];
  sprintf(fname, "/tmp/.ofrates-tmp-file-%s-%d.txt", brname, getpid());

  for (;;) {
    sleep(1);

    gettimeofday(&hp0->tv, NULL);

    exec_ovs_vsctl_dump_flows(cp, fname, brname);
    read_stat_file(hp0, brname, fname);

    print_rule_stats(hp0, hp1);

    free_list(hp1);

    // Rotate
    tp = hp1;
    hp1 = hp0;
    hp0 = tp;
  }
}
