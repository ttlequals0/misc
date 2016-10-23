drop table #ControlTable
select NAME into #controltable from VPX_DVS 
declare @name varchar(60)
declare @id int
declare @pc int
declare @cc int
declare @newcnt int
while exists (select * from #controltable)
begin
    select @name = (select top 1 NAME from #ControlTable order by NAME asc)
	select @id = (select id from VPX_DVS where NAME=@name)
	select @pc = (select PORT_COUNTER from VPX_DVS where NAME=@name)
	select @cc = (select MAX( DVPORT_KEY+0 ) FROM VPX_DVPORT_MEMBERSHIP WHERE DVS_ID=@id)
	SELECT @name, @id, @pc, @cc
	if @pc < @cc
	begin
		set @newcnt = @cc +1
		print @name + ' is not good'
		UPDATE VPX_DVS SET PORT_COUNTER=@newcnt WHERE ID=@id
	end
    delete #ControlTable
    where NAME = @name
end

/* to fix
select id, NAME, PORT_COUNTER from VPX_DVS where NAME='AR-ISCSI' 
select * from VPX_DVPORT_MEMBERSHIP where DVS_ID=555 order by DVPORT_KEY 
SELECT MAX( DVPORT_KEY+0 ) FROM VPX_DVPORT_MEMBERSHIP WHERE DVS_ID=555
UPDATE VPX_DVS SET PORT_COUNTER=530 WHERE ID=555 */
