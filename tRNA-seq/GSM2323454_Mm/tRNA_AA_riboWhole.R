#=================================================================================================
# 2019-11-25.Author:Yingying Dong.Correlation analysis of count that anticodon to amino acid from 
#  tRNA-seq and count that amino acid from ribosomal protein genes. 
#=================================================================================================
library(ggplot2)
spA = 'Mm'
species = 'mouse_mm10'
rscu_path = paste0('/media/hp/disk1/DYY/reference/annotation/',species,'/')

setwd(paste0("/media/hp/disk2/DYY2/tRNA/",spA,"/seq/"))
count_array = list.files(getwd(),pattern = ".txt$") 
count_array
for (i in count_array) {
  if(FALSE){
    tRNA_count = read.table('GSM2323453_wt1Count.txt',sep = '\t',header = F)
    name = 'GSM2323453_wt1'
  }
  tRNA_count = read.table(i,sep = '\t',header = F)
  name = sub("^([^.]*).*", "\\1",i) 
  
  names(tRNA_count) = c("aa","count")
  tRNA_aa = aggregate(tRNA_count$count, by=list(Category=tRNA_count$aa), FUN=sum)
  names(tRNA_aa) = c("aa","acc_count")
  
  aa_AA = read.table(paste0("/media/hp/disk2/DYY2/tRNA/aa_AA.txt"),header = T)
  RSCU = read.table(paste0(rscu_path,'ribo_codon_fre_RSCU.txt'),header = T)
  whole = read.table(paste0(rscu_path,'ref/codon_frequency.txt'))
  
  hits_acc = aggregate(RSCU$hits,by=list(Category=RSCU$AA),FUN=sum)
  RSCU_acc = aggregate(RSCU$RSCU,by=list(Category=RSCU$AA),FUN=sum)
  whole_acc = aggregate(whole$V3,by=list(Category=whole$V2),FUN=sum)
  names(hits_acc) = c("AA","acc_hits")
  names(whole_acc) = c("AA","acc_whole")
  
  tRNA_AA = merge(tRNA_aa,aa_AA,by = "aa",all = T)
  tRNA_ribo = merge(tRNA_AA,hits_acc,by = 'AA',all = T)
  tRNA_whole = merge(tRNA_AA,whole_acc,by = 'AA',all = T)
  tRNA_ribo = tRNA_ribo[-grep("STOP",tRNA_ribo$AA),]
  tRNA_whole = tRNA_whole[-grep("STOP",tRNA_whole$AA),]
  tRNA_whole = tRNA_whole[complete.cases(tRNA_whole),]
  
  tRNA_ribo_cor = cor(tRNA_ribo$acc_count,tRNA_ribo$acc_hits)
  tRNA_ribo_cor
  tRNA_ribo_p = cor.test(tRNA_ribo$acc_count,tRNA_ribo$acc_hits)
  p_v = tRNA_ribo_p$p.value
  
  p <- ggplot(tRNA_ribo,aes(x = log(tRNA_ribo$acc_count),y = log(tRNA_ribo$acc_hits),colour = tRNA_ribo$aa))+
    geom_point(shape = 16,size = 1.25)+
    labs(title = paste0(name,"cor_tRNA_ribo\t","r=",round(tRNA_ribo_cor,5),"\tp=",round(p_v,5)))+
    annotation_logticks(sides="bl")+
    stat_smooth(method="lm", se=FALSE,linetype="dashed", color = "black",size = 0.75)+
    theme_bw()+
    xlab("log(tRNA AA count)")+
    ylab("log(ribosomal protein AA count)")+
    theme_classic()+
    geom_text(aes(label=aa), size=4,vjust = 0, nudge_y = 0.1,check_overlap = TRUE)
  p
  ggsave(paste0(name,"cor_tRNA_ribo.pdf"), p, width = 11, height = 8.5) 
  
  tRNA_whole_cor = cor(tRNA_whole$acc_count,tRNA_whole$acc_whole)
  tRNA_whole_cor
  tRNA_whole_p = cor.test(tRNA_whole$acc_count,tRNA_whole$acc_whole)
  p1 <- ggplot(tRNA_whole,aes(x = log(tRNA_whole$acc_count),y = log(tRNA_whole$acc_whole),colour = tRNA_whole$aa))+
    geom_point(shape = 16,size = 1.25)+
    labs(title = paste0(name,"cor_tRNA_whole\t","r=",round(tRNA_whole_cor,5),"\tp=",round(tRNA_ribo_p$p.value,5)))+
    annotation_logticks(sides="bl")+
    stat_smooth(method="lm", se=FALSE,linetype="dashed", color = "black",size = 0.75)+
    theme_bw()+
    xlab("log(tRNA AA count)")+
    ylab("log(whole genome AA count)")+
    theme_classic()+
    geom_text(aes(label=aa), size=4,vjust = 0, nudge_y = 0.1,check_overlap = TRUE)
  p1
  ggsave(paste0(name,"cor_tRNA_whole.pdf"),p1,width = 11, height = 8.5)
}
