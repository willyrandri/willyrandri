USE [*your_db_name*]
GO
/****** Object:  StoredProcedure [dbo].[SP_TransactionSummary]    Script Date: 01/01/1997 00:00:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER proc  [dbo].[SP_SummaryPerInterval]
@PageNum int,,
@PageSize int,,
@StartDate varchar(10), 
@EndDate varchar(10), 
@minuteInterval bigint,
@top int,
@merchantid int,
@orderColumn varchar(50),
@orderDir varchar(5)
as

SET NOCOUNT ON;

if (@orderColumn = '')
	set @orderColumn='totalTransaction'

if (@orderDir = '')
	set @orderDir='DESC'

if (@orderColumn = 'DateInterval' or @orderColumn='TimeInterval')
	set @orderColumn = 'Interval'
	

if (@top = 0)
	set @top= 1000

if (@minuteInterval = 0)
	set @minuteInterval=60

create table #TblInterval  (
dtinterval datetime
)

declare @subquery nvarchar(max)=''
declare @buildqry nvarchar(max)=''
declare @orderbyin varchar(max)= ' xxx.' + @orderColumn + ' ' + @orderDir
declare @orderbyout varchar(max)=' a.' + @orderColumn + ' ' + @orderDir

declare @selectandgroupby nvarchar(max)='dateadd(minute,(datediff(minute,0,gh.CreatedDateD)/' + cast(@minuteInterval as varchar(10)) + ')*' + cast(@minuteInterval as varchar(10)) + ',0)'

if (@orderColumn <> 'Interval')
begin
 set @orderbyin = @orderbyin + ', xxx.Interval asc'
 set @orderbyout = @orderbyout + ', a.Interval asc'
end
if (@currencyid <> 0)
begin
 set @subquery = @subquery + ' and v.CurrencyId = ' + cast(@currencyid as varchar(5))
end

declare @dtStart datetime = cast((@StartDate + ' 00:00:00') as datetime)
declare @dtEnd datetime = cast((@EndDate + ' 23:59:59') as datetime) --dateadd(day,1, @dtStart)

while (@dtStart < @dtEnd)
begin
 insert into #TblInterval select @dtStart
 set @dtStart = dateadd(minute, @minuteInterval, @dtStart)
end

set @buildqry='

declare @activeCustomer bigint

select @activeCustomer=Count(distinct gh.CustomerID)
from VwTransaction gh
join Business v on v.Id=gh.BusinessID
where cast(gh.CreatedDate as date)>=''' + @StartDate + ''' and cast(gh.CreatedDate as date)<=''' + @TEndDate + '''' + @subquery + '

select 
Total = COUNT(*) OVER(), 
Sum_ActiveCustomer = @activeCustomer,
Sum_TotalTransaction = sum(a.TotalTransaction) over(),
format(a.Interval,''yyyy-MM-dd'') DateInterval, format(a.Interval,''HH:mm:ss'') + '' - '' + format(dateadd(second,(60*' + cast(@minuteInterval as varchar(10)) + ') -1, a.Interval), ''HH:mm:ss'')  TimeInterval, a.ActiveCustomer, a.TotalTransaction
from
(

select
top(' + cast(@top as varchar(15)) + ') *
from
(

select a.dtinterval Interval, isnull(b.ActiveCustomer,0) ActiveCustomer, isnull(b.TotalTransaction,0) TotalTransaction from #TblInterval a
left join
(
SELECT  COUNT(*) TotalTransaction,Count(distinct gh.CustomerID) ActiveCustomer, ' + @selectandgroupby + ' [Interval] 
FROM VwTransaction gh
join Business v on v.Id=gh.BusinessId
where cast(gh.CreatedDate as date)>=''' + @StartDate + ''' and cast(gh.CreatedDate as date)<=''' + @EndDate + '''
' + @subquery + '
GROUP BY ' + @selectandgroupby + ' 
) b on a.dtinterval = b.Interval

) xxx
order by ' + @orderbyin + '

) a
order by ' + @orderbyout + '
OFFSET ' + cast(((@PageNum-1)*@PageSize) as nvarchar(20))  + ' ROWS 
FETCH NEXT ' + cast(@PageSize as nvarchar(20)) + ' ROWS ONLY'
exec(@buildqry)
drop table #TblInterval
