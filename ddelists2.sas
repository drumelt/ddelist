
data delist.prcret;
set bb.daily ;
year=year(date);
attrib ldecade length=$7 label="Period Label";
select;
	when (year in(1925:1930)) ldecade="1926-30";
	when (year in(1931:1940)) ldecade="1931-40";
	when (year in(1941:1950)) ldecade="1941-50";
	when (year in(1951:1960)) ldecade="1951-60";
	when (year in(1961:1970)) ldecade="1961-70";
	when (year in(1971:1980)) ldecade="1971-80";
	when (year in(1981:1990)) ldecade="1981-90";
	when (year in(1991:2000)) ldecade="1991-00";
	when (year in(2001:2010)) ldecade="2001-10";
	when (year in(2011:2020)) ldecade="2011-20";
end;
dlret2 = dlret;
attrib dltype length=$12 label="Type of Delisting";
if ~missing(dlstcd) and dlstcd > 199 then do;
	select;
		when (dlstcd in(200:271,280,290)) dltype= "Merger";
		when (dlstcd in(300:371)) dltype="Exchange";
		when (dlstcd in(400:490)) dltype= "Liquidation";
		when (dlstcd in(501:520)) dltype= "DiffExchange";
		when (dlstcd in(535:591)) dltype = "Performance";
		when (dlstcd in (280,390,500,900:903)) dltype="Other";
		otherwise dltype= "Problem";
	end;
	if dltype="Problem" then do;
		put dltype= dlstcd=;
		abort;
	end;
	if dlret=.T then do;
		dlval = max(dlamt,dlprc);
		if ~missing(dlval) and ~missing(prc) then dlret1=divide(dlval, prc)-1;
		dlret2 = coalesce(dlret, dlret1);
	end;
end;
keep permno date year ldecade ret ret_L retx retx_L dlret dlret1 dlret2 dlamt dlprc dlstcd dltype prc prc_L ewretd ewretx ewretd_L ewretx_L;
run;

data delist.prcdlret; 
set delist.prcret;
if not missing(dlstcd) and dlstcd > 199;
run;
proc sort data=delist.prcdlret;
by ldecade year;
run;


ods html file="C:\Users\Richard\Dropbox\Richard\_locus of points\Finance\Fan\Delistings\drun20211018.html";
Title;
%macro tofan(thefile);
proc export
	data = delist.&thefile
	dbms = xlsx
	outfile = "C:\Users\Richard\Dropbox\Richard\_locus of points\Finance\Fan\Delistings\&thefile"
	replace;
run;
%mend;



%macro docorr(infile,var1, var2, byvar, outfile);
Title Correlation &var1 with &var2 by &byvar into &outfile.b;
proc corr data=&infile nomiss outp=&outfile;
%if %sysevalf(%superq(byvar) ne,boolean) %then %do;
	by &byvar;
%end;
var &var1 &var2;
run;
data &outfile.a;
set &outfile;
if _TYPE_="CORR" and _NAME_="&var1";
corr = &var2;
keep corr %if %sysevalf(%superq(byvar) ne,boolean) %then %do;
	&byvar;
%end;
keep corr &byvar;
run;
data &outfile.b;
format numcorr corr;
merge &outfile.a &outfile.(where=(_type_="N"));
%if %sysevalf(%superq(byvar) ne,boolean) %then %do;
	by &byvar;
%end;
Numcorr=&var1;
keep numcorr corr %if %sysevalf(%superq(byvar) ne,boolean) %then %do;
	&byvar; %end;
run;
%mend;

%docorr(delist.prcret,RET, ret_L,,delist.coretret);
%docorr(delist.prcret,RET, ret_L, ldecade,delist.coretret_dec);
%docorr(delist.prcret, ewretd, ewretd_L,, delist.corewretret);
%docorr(delist.prcret, ewretd, ewretd_L, ldecade, delist.corewretret_dec);
%docorr(delist.prcdlret, RET, dlret2,,delist.corretdlret);
%docorr(delist.prcdlret, RET, dlret2,ldecade, delist.corretdlret_dec);

proc sql;
create table delist.count_delistings as
select	count(~missing(dlstcd)) as ndelists, sum(~missing(dlret)) as ndlret, 
sum(~missing(dlret2)) as ndlret2
from delist.prcdlret
group by ldecade
order by ldecade;
quit;

/*Repead ldecade logic because using msf here */
proc sql;
create table delist.count_permnos as
select distinct year(date) as year, count(permno) as np,
	case 
	when calculated year in(1926:1930) then  '1926-30'
	when calculated year in(1931:1940) then  '1931-40'
	when calculated year in(1941:1950) then  '1941-50'
	when calculated year in(1951:1960) then  '1951-60'
	when calculated year in(1961:1970) then  '1961-70'
	when calculated year in(1971:1980) then  '1971-80'
	when calculated year in(1981:1990) then  '1981-90'
	when calculated year in(1991:2000) then  '1991-00'
	when calculated year in(2001:2010) then  '2001-10'
	when calculated year in(2011:2020) then  '2011-20'
	end as ldecade format=$7.
from crsp.msf (keep=permno date where=(month(date)=1))
group by calculated year
order by calculated ldecade, calculated year;
quit;
%tofan(count_permnos);

%macro domeans(thevar,theclass);
Title &thevar._&theclass;
proc means data=delist.prcdlret n nmiss mean median stddev min max;
class &theclass;
var &thevar;
output out=delist.&thevar._by_&theclass
	n= nmiss= mean= median= stddev= min= max= /autoname;
run;
%tofan(&thevar._by_&theclass);
%mend;
%domeans(dlret,ldecade);
%domeans(dlret1,ldecade);
%domeans(dlret2,year);
%domeans(dlret2,ldecade);
%domeans(dlret,dlstcd);
%domeans(dlret2,dlstcd);
%domeans(dlret,dltype);
%domeans(dlret2,dltype);


Title mixed dlret2=[dlstcd]
ods output solutionr=delist.mix_dl2_cd_R;
proc mixed data=delist.prcdlret;
class dlstcd;
model dlret2 = /s noint ;
random dlstcd /s;
run;
%tofan(mix_dl2_cd_R);

Title mixed dlret2= ret [dlstcd];
ods output solutionf=delist.mix_dl2_ret_cd_F;
ods output solutionr=delist.mix_dl2_ret_cd_R;
proc mixed data=delist.prcdlret;
class dlstcd;
model dlret2 = ret/s noint ;
random dlstcd /s;
run;
%tofan(mix_dl2_ret_cd_F);
%tofan(mix_dl2_ret_cd_R);


Title mixed dlret2= ret [dlstcd] ret*dlstcd;
ods output solutionf=delist.mix_dl2_ret_cd_2_F;
ods output solutionr=delist.mix_dl2_ret_cd_2_R;
proc mixed data=delist.prcdlret;
class dlstcd;
model dlret2 = ret*dlstcd/s noint ;
random dlstcd /s;
run;
%tofan(mix_dl2_ret_cd_2_F);
%tofan(mix_dl2_ret_cd_2_R);

Title mixed dlret2 = [dltype];
ods output solutionr=delist.mix_dl2_ret_ty_R;
proc mixed data=delist.prcdlret;
class dltype;
model dlret2 = /s noint ;
random dltype /s;
run;
%tofan(mix_dl2_ret_ty_R);

Title mixed dlret2 = ret [dltype];
ods output solutionf=delist.mix_dl2_ret_ty_F;
ods output solutionr=delist.mix_dl2_ret_ty_R;
proc mixed data=delist.prcdlret;
class dltype;
model dlret2 = ret /s noint ;
random dltype /s;
run;
%tofan(mix_dl2_ret_ty_F);
%tofan(mix_dl2_ret_ty_R);

Title mixed dlret2 = ret [dltype] ret*dltype;
ods output solutionf=delist.mix_dl2_ret_ty_2_F;
ods output solutionr=delist.mix_dl2_ret_ty_2_R;
proc mixed data=delist.prcdlret;
class dltype;
model dlret2 = ret*dltype/s noint ;
random dltype /s;
run;
%tofan(mix_dl2_ret_ty_2_F);
%tofan(mix_dl2_ret_ty_2_R);


ods _all_ close;

