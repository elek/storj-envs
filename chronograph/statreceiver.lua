-- possible sources:
--  * udpin(address)
--  * filein(path)
-- multiple sources can be handled in the same run (including multiple sources
-- of the same type) by calling deliver more than once.
source = udpin(":9000")

-- These two numbers are the size of destination metric buffers and packet buffers
-- respectively. Wrapping a metric destination in a metric buffer starts a goroutine
-- for that destination, which allows for concurrent writes to destinations, instead
-- of writing to destinations synchronously. If one destination blocks, this allows
-- the other destinations to continue, with the caveat that buffers may get overrun
-- if the buffer fills past this value.
-- One additional caveat to make sure mbuf and pbuf work - they need mbufprep and
-- pbufprep called higher in the pipeline. By default to save CPU cycles, memory
-- is reused, but this is bad in buffered writer situations. mbufprep and pbufprep
-- stress the garbage collector and lower performance at the expense of getting
-- mbuf and pbuf to work.
-- I've gone through and added mbuf and pbuf calls in various places. I think one
-- of our output destinations was getting behind and getting misconfigured, and
-- perhaps that was causing the holes in the data.
-- - JT 2019-05-15
mbufsize = 10000
pbufsize = 1000

-- multiple metric destination types
--  * graphite(address) goes to tcp with the graphite wire protocol
--  * print() goes to stdout
--  * db("sqlite3", path) goes to sqlite
--  * db("postgres", connstring) goes to postgres

influx_base = "http://influxdb:8086"
influx_user = os.getenv("INFLUX_USERNAME")
influx_pass = os.getenv("INFLUX_PASSWORD")

v3_url = string.format("%s/write?db=v3_stats_new&u=%s&p=%s",influx_base, influx_user, influx_pass)

influx_out_v3 = influx(v3_url)

--    mbuf(graphite_out_stefan, mbufsize),
  -- send specific storagenode data to the db
    --keyfilter(
      --"env\\.process\\." ..
        --"|hw\\.disk\\..*Used" ..
        --"|hw\\.disk\\..*Avail" ..
        --"|hw\\.network\\.stats\\..*\\.(tx|rx)_bytes\\.(deriv|val)",
      --mbuf(db_out, mbufsize))



v3_metric_handlers = mbufprep(mbuf("influx_new", influx_out_v3, mbufsize))

allowed_instance_id_applications = "(satellite|retrievability|webproxy|gateway-mt|linksharing|authservice)"

-- create a metric parser.
metric_parser = parse(zeroinstanceifnot(allowed_instance_id_applications, v3_metric_handlers))

    --packetfilter(".*", "", udpout("localhost:9002")))
    --packetfilter("(storagenode|satellite)-(dev|prod|alphastorj|stagingstorj)", ""))

af = "(linksharing|gateway-mt|authservice|satellite|retrievability-checker|downloadData|uploadData|webproxy).*(-alpha|-release|storj|-transfersh)"

-- pcopy forks data to multiple outputs
-- output types include parse, fileout, and udpout
destination = pbufprep(pcopy(
  fileout("dump.out"),


  pbuf(packetfilter(af, "", nil, fileout("af.out")), pbufsize),
  
  pbuf(packetfilter(".*", "", nil, metric_parser), pbufsize),

  -- useful local debugging
  pbuf(udpout("receiver:9000"), pbufsize)

   -- uplink
   --pbuf(packetfilter("uplink", "", uplink_header_matcher, packetprint()), pbufsize)
 ))

-- tie the source to the destination
deliver(source, destination)


