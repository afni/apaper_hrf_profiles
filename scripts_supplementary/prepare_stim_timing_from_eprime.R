#Script to process raw behavioral files from Task dataset, quality
#check files, produce timing files Script requires tab delimited
#exported eprime file

###read in the raw data from the scanner
Task_raw <- ""
setwd(paste0("INPUT_PATH"))
group_list <- list.files(pattern=".txt")
i=1
for (Grp in group_list){
    print(Grp)
    fName<-paste0(Grp)
    Raw<-read.table(file=fName,sep="\t",header=T, stringsAsFactors = F)
    db<-Raw[c("Subject", "Session", "SessionDate", "Welcome.FinishTime", 
              "CkScan.FinishTime", "OverallAccuracy", "Img" , "Fix.ACC", 
              "Fix.RT", "Global1", "Global2", "Global3", "Local1", 
              "Local2", "Local3", "Run1", "Run2", "Run3", "Run4", "Run5", 
              "Run6", "Tgt.OnsetTime")]
    Task_raw<-rbind(Task_raw,db)
  }

Task_raw<-Task_raw[-1,]
rm(Raw,db)

#find the onset time 
Task_raw$Scan.Offset <-NA
Task_raw$Scan.Offset<-Task_raw$CkScan.FinishTime

require(dplyr)
require(tidyr)
Task_raw <-Task_raw %>% 
  fill(Scan.Offset , .direction = "down")

table(Task_raw$Subject)
Task_raw<-Task_raw[Task_raw$Subject %in% names(table(Task_raw$Subject))[table(Task_raw$Subject) == 582],]

#rename variables
Task_raw <- Task_raw %>% mutate(Global1 = ifelse(is.na(Global1), Global1, "Global1"))
Task_raw <- Task_raw %>% mutate(Global2 = ifelse(is.na(Global2), Global2, "Global2"))
Task_raw <- Task_raw %>% mutate(Global3 = ifelse(is.na(Global3), Global3, "Global3"))
Task_raw <- Task_raw %>% mutate(Local1 = ifelse(is.na(Local1), Local1, "Local1"))
Task_raw <- Task_raw %>% mutate(Local2 = ifelse(is.na(Local2), Local2, "Local2"))
Task_raw <- Task_raw %>% mutate(Local3 = ifelse(is.na(Local3), Local3, "Local3"))
Task_raw$Condition<-NA
Task_raw$Condition <- ifelse(is.na(Task_raw$Condition), Task_raw$Global1, Task_raw$Condition)
Task_raw$Condition <- ifelse(is.na(Task_raw$Condition), Task_raw$Local1, Task_raw$Condition)
Task_raw$Condition <- ifelse(is.na(Task_raw$Condition), Task_raw$Global2, Task_raw$Condition)
Task_raw$Condition <- ifelse(is.na(Task_raw$Condition), Task_raw$Local2, Task_raw$Condition)
Task_raw$Condition <- ifelse(is.na(Task_raw$Condition), Task_raw$Global3, Task_raw$Condition)
Task_raw$Condition <- ifelse(is.na(Task_raw$Condition), Task_raw$Local3, Task_raw$Condition)

#quality check number of trials
table(Task_raw$Subject, Task_raw$Condition)

Task_raw <- Task_raw %>% 
  group_by(Subject,Condition) %>%
  filter(n() == 93) %>% 
  ungroup()
  
table(Task_raw$Subject, Task_raw$Condition) 

Task_raw <- Task_raw %>% 
  group_by(Subject,Img) %>%
  filter(n() == 138) %>% 
  ungroup()

table(Task_raw$Subject, Task_raw$Img) 

#rename trial type
Task_raw$TrialType <-recode_factor(Task_raw$Img, "HH" = "C", "SS" = "C", "SH" = "IC", "HS" = "IC")

#make sure variables are coded correctly
dataframe <- Task_raw 
dataframe$Subject<-as.factor(dataframe$Subject)
dataframe$Session<-as.factor(dataframe$Session)
dataframe$TrialType<-as.factor(dataframe$TrialType)
dataframe$Condition<-as.factor(dataframe$Condition)
dataframe$Fix.RT<-as.numeric(dataframe$Fix.RT)
dataframe$Fix.RT<-dataframe$Fix.RT + 200
dataframe$Tgt.OnsetTime<-as.numeric(dataframe$Tgt.OnsetTime)
dataframe$Scan.Offset<-as.numeric(dataframe$Scan.Offset)

#make sure dates are redable to match to scan date
library(lubridate)
mdy <- mdy(dataframe$SessionDate) 
ymd <- ymd(dataframe$SessionDate) 
dmy <- dmy(dataframe$SessionDate) 
dataframe$SessionDate <- mdy        # mdy precedence over dmy


####lets make timingfiles
setwd("~/Desktop/timingfiles/")
dataframe %>% distinct(dataframe$Subject, dataframe$SessionDate, dataframe$Session)

#WM_timings<-subset(dataframe, dataframe$TrialType=="C" & dataframe$Fix.ACC=="1")

for (subj in unique(dataframe$Subject)){
  attach(dataframe)
  timingdata1<-dataframe[Subject==subj,]
  detach(dataframe)
  
  # Make StimTimes relative to the scan trigger time 
  # (in ms) and subtract magnetization time (6 TRs = 1.250*6=7.5 ms)
  # E Prime waited for 7.5 ms before presenting the first stimulus.
  # So we have enough lead time to clip 6 TRs
  timingdata1$Run<-rep(c(1:6),each=92)
  timingdata<-subset(timingdata1, timingdata1$Fix.ACC=="1")
  
  timingdata$StimTime<-(as.numeric(timingdata$Tgt.OnsetTime))-(as.numeric(timingdata$Scan.Offset))
  timingdata<-timingdata %>% select (Subject, SessionDate, TrialType, Tgt.OnsetTime, Fix.RT, Condition, Run, StimTime) %>% 
    group_by(TrialType, Condition) %>% mutate(Mrun_con = mean(Fix.RT))%>% ungroup %>% mutate (AMRT = Fix.RT-Mrun_con)
  
  Run1.Congruent<-subset(timingdata,timingdata$TrialType=="C" & timingdata$Run=="1")
  Run1.Congruent$StimTimeFinal<-Run1.Congruent$StimTime/1000
  Run1.Congruent$AMRT<-round(Run1.Congruent$AMRT, digits = 2)
  dur1<-Run1.Congruent$AMRT
  Run1.Congruent<-Run1.Congruent$StimTimeFinal
  Run1.Congruent.AM<-paste0(Run1.Congruent,'*',dur1)
  if(length(Run1.Congruent)==0){Run1.Congruent<-"*"}
  
  Run2.Congruent<-subset(timingdata, timingdata$TrialType=="C" & timingdata$Run=="2")
  Run2.Congruent$StimTimeFinal<-Run2.Congruent$StimTime/1000
  Run2.Congruent$AMRT<-round(Run2.Congruent$AMRT, digits = 2)
  dur2<-Run2.Congruent$AMRT
  Run2.Congruent<-Run2.Congruent$StimTimeFinal
  Run2.Congruent.AM<-paste0(Run2.Congruent,'*',dur2)
  if(length(Run2.Congruent.AM)==0){Run2.Congruent<-"*"}
  
  Run3.Congruent<-subset(timingdata, timingdata$TrialType=="C" & timingdata$Run=="3")
  Run3.Congruent$StimTimeFinal<-Run3.Congruent$StimTime/1000
  Run3.Congruent$AMRT<-round(Run3.Congruent$AMRT, digits = 2)
  dur3<-Run3.Congruent$AMRT
  Run3.Congruent<-Run3.Congruent$StimTimeFinal
  Run3.Congruent.AM<-paste0(Run3.Congruent,'*',dur3)
  if(length(Run3.Congruent.AM)==0){Run3.Congruent<-"*"}
  
  Run4.Congruent<-subset(timingdata, timingdata$TrialType=="C" & timingdata$Run=="4")
  Run4.Congruent$StimTimeFinal<-Run4.Congruent$StimTime/1000
  Run4.Congruent$AMRT<-round(Run4.Congruent$AMRT, digits = 2)
  dur4<-Run4.Congruent$AMRT
  Run4.Congruent<-Run4.Congruent$StimTimeFinal
  Run4.Congruent.AM<-paste0(Run4.Congruent,'*',dur4)
  if(length(Run4.Congruent.AM)==0){Run4.Congruent<-"*"}
  
  Run5.Congruent<-subset(timingdata, timingdata$TrialType=="C" & timingdata$Run=="5")
  Run5.Congruent$StimTimeFinal<-Run5.Congruent$StimTime/1000
  Run5.Congruent$AMRT<-round(Run5.Congruent$AMRT, digits = 2)
  dur5<-Run5.Congruent$AMRT
  Run5.Congruent<-Run5.Congruent$StimTimeFinal
  Run5.Congruent.AM<-paste0(Run5.Congruent,'*',dur5)
  if(length(Run5.Congruent.AM)==0){Run5.Congruent<-"*"}
  
  Run6.Congruent<-subset(timingdata, timingdata$TrialType=="C" & timingdata$Run=="6")
  Run6.Congruent$StimTimeFinal<-Run6.Congruent$StimTime/1000
  Run6.Congruent$AMRT<-round(Run6.Congruent$AMRT, digits = 2)
  dur6<-Run6.Congruent$AMRT
  Run6.Congruent<-Run6.Congruent$StimTimeFinal
  Run6.Congruent.AM<-paste0(Run6.Congruent,'*',dur6)
  if(length(Run6.Congruent.AM)==0){Run6.Congruent<-"*"}
  
  setwd("~/Desktop/timingfiles/")
  dir.create(paste0("sub-s",subj,"/ses-1"), recursive = TRUE)
  setwd(paste0("~/Desktop/timingfiles/sub-s",subj,"/ses-1"))
  
  timingdata$Subject<-as.character(timingdata$Subject)
  subj<-subj
  date<-timingdata$SessionDate[1]
  cat(Run1.Congruent.AM,"\n", Run2.Congruent.AM,"\n",Run3.Congruent.AM,"\n",Run4.Congruent.AM, "\n",Run5.Congruent.AM, "\n",Run6.Congruent.AM, file=paste0("Con_corr_s",subj,"-",date,"AM.1D"))
  cat(Run1.Congruent,"\n", Run2.Congruent,"\n", Run3.Congruent,"\n", Run4.Congruent,"\n", Run5.Congruent,"\n", Run6.Congruent, file=paste0("Con_corr_s",subj,"-",date,".1D"))
  rm(Run1.Congruent, Run2.Congruent, Run3.Congruent, Run4.Congruent, Run5.Congruent, Run6.Congruent, dur1,dur2,dur3,dur4,dur5,dur6, Run1.Congruent.AM, Run2.Congruent.AM, 
     Run3.Congruent.AM, Run4.Congruent.AM, Run5.Congruent.AM, Run6.Congruent.AM)
  
  
  Run1.InCongruent<-subset(timingdata, timingdata$TrialType=="IC" & timingdata$Run=="1")
  Run1.InCongruent$StimTimeFinal<-Run1.InCongruent$StimTime/1000
  Run1.InCongruent$AMRT<-round(Run1.InCongruent$AMRT, digits = 2)
  dur1<-Run1.InCongruent$AMRT
  Run1.InCongruent<-Run1.InCongruent$StimTimeFinal
  Run1.InCongruent.AM<-paste0(Run1.InCongruent,'*',dur1)
  if(length(Run1.InCongruent)==0){Run1.InCongruent<-"*"}
  
  Run2.InCongruent<-subset(timingdata, timingdata$TrialType=="IC" & timingdata$Run=="2")
  Run2.InCongruent$StimTimeFinal<-Run2.InCongruent$StimTime/1000
  Run2.InCongruent$AMRT<-round(Run2.InCongruent$AMRT, digits = 2)
  dur2<-Run2.InCongruent$AMRT
  Run2.InCongruent<-Run2.InCongruent$StimTimeFinal
  Run2.InCongruent.AM<-paste0(Run2.InCongruent,'*',dur2)
  if(length(Run2.InCongruent.AM)==0){Run2.InCongruent<-"*"}
  
  Run3.InCongruent<-subset(timingdata,  timingdata$TrialType=="IC" & timingdata$Run=="3")
  Run3.InCongruent$StimTimeFinal<-Run3.InCongruent$StimTime/1000
  Run3.InCongruent$AMRT<-round(Run3.InCongruent$AMRT, digits = 2)
  dur3<-Run3.InCongruent$AMRT
  Run3.InCongruent<-Run3.InCongruent$StimTimeFinal
  Run3.InCongruent.AM<-paste0(Run3.InCongruent,'*',dur3)
  if(length(Run3.InCongruent)==0){Run3.InCongruent<-"*"}
  
  Run4.InCongruent<-subset(timingdata, timingdata$TrialType=="IC" & timingdata$Run=="4")
  Run4.InCongruent$StimTimeFinal<-Run4.InCongruent$StimTime/1000
  Run4.InCongruent$AMRT<-round(Run4.InCongruent$AMRT, digits = 2)
  dur4<-Run4.InCongruent$AMRT
  Run4.InCongruent<-Run4.InCongruent$StimTimeFinal
  Run4.InCongruent.AM<-paste0(Run4.InCongruent,'*',dur4)
  if(length(Run4.InCongruent)==0){Run4.InCongruent<-"*"}
  
  Run5.InCongruent<-subset(timingdata, timingdata$TrialType=="IC" & timingdata$Run=="5")
  Run5.InCongruent$StimTimeFinal<-Run5.InCongruent$StimTime/1000
  Run5.InCongruent$AMRT<-round(Run5.InCongruent$AMRT, digits = 2)
  dur5<-Run5.InCongruent$AMRT
  Run5.InCongruent<-Run5.InCongruent$StimTimeFinal
  Run5.InCongruent.AM<-paste0(Run5.InCongruent,'*',dur5)
  if(length(Run5.InCongruent)==0){Run5.InCongruent<-"*"}
  
  Run6.InCongruent<-subset(timingdata, timingdata$TrialType=="IC" & timingdata$Run=="6")
  Run6.InCongruent$StimTimeFinal<-Run6.InCongruent$StimTime/1000
  Run6.InCongruent$AMRT<-round(Run6.InCongruent$AMRT, digits = 2)
  dur6<-Run6.InCongruent$AMRT
  Run6.InCongruent<-Run6.InCongruent$StimTimeFinal
  Run6.InCongruent.AM<-paste0(Run6.InCongruent,'*',dur6)
  if(length(Run6.InCongruent)==0){Run6.InCongruent<-"*"}
  
  setwd(paste0("~/Desktop/timingfiles/sub-s",subj,"/ses-1"))
  timingdata$Subject<-as.character(timingdata$Subject)
  subj<-subj
  date<-timingdata$SessionDate[1]
  cat(Run1.InCongruent.AM,"\n", Run2.InCongruent.AM,"\n",Run3.InCongruent.AM,"\n",Run4.InCongruent.AM, "\n",Run5.InCongruent.AM, "\n",Run6.InCongruent.AM, file=paste0("Incon_cor_s",subj,"-",date,"AM.1D"))
  cat(Run1.InCongruent,"\n", Run2.InCongruent,"\n", Run3.InCongruent,"\n", Run4.InCongruent,"\n",Run5.InCongruent, "\n",Run6.InCongruent, file=paste0("Incon_cor_s",subj,"-",date,".1D"))
  rm(Run1.InCongruent, Run2.InCongruent, Run3.InCongruent, Run4.InCongruent, Run5.InCongruent, Run6.InCongruent,dur1,dur2,dur3,dur4,dur5, dur6, 
     Run1.InCongruent.AM, Run2.InCongruent.AM, Run3.InCongruent.AM, Run4.InCongruent.AM, Run5.InCongruent.AM, Run6.InCongruent.AM)
  
}
  
#Wrrong and missed resp

for (subj in unique(dataframe$Subject)){
  attach(dataframe)
  timingdata2<-dataframe[Subject==subj,]
  detach(dataframe)
  timingdata2$Run<-rep(c(1:6),each=92)
  timingdata<-subset(timingdata2, timingdata2$Fix.ACC=="0")
  timingdata$StimTime<-(as.numeric(timingdata$Tgt.OnsetTime))-(as.numeric(timingdata$Scan.Offset))
  timingdata<-timingdata %>% select (Subject, SessionDate, TrialType, Tgt.OnsetTime, Fix.RT, Condition, Run, StimTime)
  
  Run1.Omission<-subset(timingdata, timingdata$Run=="1" )
  Run1.Omission$StimTimeFinal<-Run1.Omission$StimTime/1000
  Run1.Omission<-Run1.Omission$StimTimeFinal
  if(length(Run1.Omission)==0){Run1.Omission<-"*"}
  
  Run2.Omission<-subset(timingdata, timingdata$Run=="2")
  Run2.Omission$StimTimeFinal<-Run2.Omission$StimTime/1000
  Run2.Omission<-Run2.Omission$StimTimeFinal
  if(length(Run2.Omission)==0){Run2.Omission<-"*"}
  
  Run3.Omission<-subset(timingdata, timingdata$Run=="3")
  Run3.Omission$StimTimeFinal<-Run3.Omission$StimTime/1000
  Run3.Omission<-Run3.Omission$StimTimeFinal
  if(length(Run3.Omission)==0){Run3.Omission<-"*"}
  
  Run4.Omission<-subset(timingdata, timingdata$Run== "4")
  Run4.Omission$StimTimeFinal<-Run4.Omission$StimTime/1000
  Run4.Omission<-Run4.Omission$StimTimeFinal
  if(length(Run4.Omission)==0){Run4.Omission<-"*"}
  
  Run5.Omission<-subset(timingdata, timingdata$Run=="5")
  Run5.Omission$StimTimeFinal<-Run5.Omission$StimTime/1000
  Run5.Omission<-Run5.Omission$StimTimeFinal
  if(length(Run5.Omission)==0){Run5.Omission<-"*"}
  
  Run6.Omission<-subset(timingdata, timingdata$Run== "6")
  Run6.Omission$StimTimeFinal<-Run6.Omission$StimTime/1000
  Run6.Omission<-Run6.Omission$StimTimeFinal
  if(length(Run6.Omission)==0){Run6.Omission<-"*"}
  
  setwd(paste0("~/Desktop/timingfiles/sub-s",subj,"/ses-1"))
  timingdata$Subject<-as.character(timingdata$Subject)
  subj<-subj
  date<-timingdata$SessionDate[1]
  cat(Run1.Omission,"\n", Run2.Omission,"\n", Run3.Omission,"\n", Run4.Omission,"\n", Run5.Omission,"\n", Run6.Omission,file=paste0("Error_s",subj,"-",date,".1D"))
  rm(Run1.Omission, Run2.Omission, Run3.Omission, Run4.Omission,Run5.Omission,Run6.Omission)
  
}
