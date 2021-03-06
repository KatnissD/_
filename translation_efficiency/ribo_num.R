#============================================================================================== 
# 2019-7-29.Modified date:2020-1-10.Author:Dong Yingying.Roughly  observe the translation efficiency.
# Translation efficiency is subtracted from the TPM value quantified by a sample of 
# RNAseq transcripts and the corresponding TPM value of the RIBO-seq transcript(same lab).
# And take out genes that express high expression and high translation level.
#==============================================================================================
library(ggplot2)
library(MASS)
library(scales)
species = "Saccharomyces_cerevisiae"
KEGG_spe = "Saccharomyces cerevisiae"
exp = "experiment2"
RNAnum = "SRR4175342_abund.out"
setwd(paste0("~/Desktop/other_riboseq/",species,"/",exp,"/aligned/"))
dir.create("ribo_num")
RNA = read.table(RNAnum,sep = "\t",header = T,quote = "")
RNA = RNA[,-c(3,4,5,6,7)]
RIBOnum = "SRR4175354_abund.out"
ribo = read.table(paste0("../aligned_ri/",RIBOnum),sep = "\t",header = T,quote = "")
name = RIBOnum
name = sub("^([^.]*).*", "\\1",name)
name = gsub("_abund","",name)
ribo = ribo[,-c(2,3,4,5,6,7)]
names(ribo) = c("Gene.ID","ribo_FPKM","ribo_TPM")
RNA_ribo = merge(RNA,ribo,by = "Gene.ID",all = T)
RNA_ribo[RNA_ribo == 0] <-NA
RNA_ribo = RNA_ribo[complete.cases(RNA_ribo),]
#RNA_ribo_num = cbind(RNA_ribo,round(RNA_ribo$TPM / RNA_ribo$ribo_TPM,3))
ribo_num = round(RNA_ribo$ribo_TPM / RNA_ribo$TPM,3)
RNA_ribo_num = cbind(RNA_ribo,ribo_num)
RNA_ribo_num = RNA_ribo_num[order(RNA_ribo_num$ribo_num,decreasing = T),]
#RNA_ribo_num$Gene.ID = gsub("_.*", "", RNA_ribo_num[,1])
write.table(RNA_ribo_num,file = paste0("./ribo_num/",name,"_riboNum.txt"),
            sep = "\t",quote = F,row.names = F)
#=================================================================================================================
# Extract genes encoding only proteins 
#=================================================================================================================
only_protein = read.table(paste0("/media/hp/disk1/DYY/reference/annotation/",species,"/ref/CBI_CAI.txt"),header = T)
only_protein = only_protein[,-c(3,4,5)]
only_protein_num = merge(RNA_ribo_num,only_protein,by.x = "Gene.ID",by.y = "transcription_id",all = T)
only_protein_num = only_protein_num[complete.cases(only_protein_num),]
only_protein_num = only_protein_num[order(only_protein_num$ribo_num,decreasing = T),]
write.table(only_protein_num,file = paste0("./ribo_num/",name,"_ProtRiboNum.txt"),
            sep = '\t',quote = F,row.names = F)
q = quantile(only_protein_num$ribo_num,probs = seq(0,1,0.01))
q
hiTE = only_protein_num[only_protein_num$ribo_num >= q[99],]
write.table(hiTE,file = paste0("./ribo_num/",name,"_highTE_all.txt"),
            sep = '\t',quote = F,row.names = F)
write.table(paste(hiTE$Gene.Name,hiTE$ribo_num,sep = "\t"),
            file = paste0("./ribo_num/",name,"_highTE_geneNAME.txt"),
            sep = '\t',quote = F,row.names = F,col.names = F)
#==================================================================================================================
# Observe the correlation between RNAseq and RIBOseq
#==================================================================================================================
co_RNA_ri = cor(only_protein_num$TPM,only_protein_num$ribo_TPM)
co_RNA_ri
p_RNA_ri = cor.test(only_protein_num$TPM,only_protein_num$ribo_TPM)
p_RNA_ri
#plot(only_protein_num$TPM,only_protein_num$ribo_TPM,log = "xy",main = paste0(name,"cor_RNA_ri  ",co_RNA_ri),
#     xlab="RNA_TPM",ylab="ri_TPM",pch=19,col=rgb(0,0,100,50,maxColorValue=205))
#compare_means(TPM~ribo_TPM, data=only_protein_num)
p <- ggplot(only_protein_num,aes(x = TPM ,y = ribo_TPM))+
  geom_point(shape = 16,size = 0.5)+
  labs(title = paste0(name,'  ',"r=",round(p_RNA_ri$estimate,5),"  p-value < 2.2e-16"))+
  #scale_x_continuous(trans='log10')+
  #scale_y_continuous(trans='log10')+
  scale_x_log10(breaks = trans_breaks("log10", function(x) 10^x),
                labels = trans_format("log10", math_format(10^.x))) +
  scale_y_log10(breaks = trans_breaks("log10", function(x) 10^x),
                labels = trans_format("log10", math_format(10^.x))) +
  annotation_logticks(sides="bl")+
  stat_smooth(method="lm", se=FALSE,linetype="dashed", color = "red",size = 0.75)+
  xlab('RNA-seq (TPM)')+
  ylab('Ribo-seq (TPM)')+
  theme_classic()+
  theme(axis.title.x =element_text(size=14), axis.title.y=element_text(size=14))
p
ggsave(paste0(name,"cor_RNA_ri.pdf"), p, width = 4.75, height = 3.15) 

write.table(co_RNA_ri,file = "cor_RNA_ri.txt",sep = '\t',append = T,quote = FALSE,
            row.names = F, col.names = F)
#==================================================================================================================
# Take out genes that express high expression and high translation level
#==================================================================================================================
df <- data.frame(only_protein_num$Gene.ID,only_protein_num$Gene.Name,only_protein_num$TPM,only_protein_num$ribo_TPM)
#gene_id = only_protein_num$Gene.Name
names(df) = c("Gene_ID","Gene_name","TPM","ribo_TPM")
threshhold <- 1
df = subset(df, df[,3] > threshhold) 
df = subset(df, df[,4] > threshhold)
#tmp <- cor(df$TPM,df$ribo_TPM)
#tmp[upper.tri(tmp)] <- 0
#data.new <- df[,!apply(tmp,2,function(x) any(x < 0.6))] #something wrong
qRNA = quantile(df$TPM,probs = seq(0,1,0.01))
qRNA
hiRNA = df[df$TPM > qRNA[95],]    # Top 5%
h2RNA = df[df$TPM > qRNA[90],]    # Top 10%
m1RNA = df[df$TPM < qRNA[45],]     # bottom 45%
m2RNA = df[df$TPM < qRNA[55],]   # Bottom 55%
lRNA = df[df$TPM < qRNA[10],]    # BOTTOM 10%
mRNA = subset(m2RNA, !m2RNA$TPM %in%c(m1RNA$TPM))  # Middle 10%

qRIBO = quantile(df$ribo_TPM,probs = seq(0,1,0.01))
qRIBO
hiRIBO = df[df$ribo_TPM > qRIBO[95],]    # TOP 5%
other_ribo = df[df$ribo_TPM < qRIBO[95],]    #In order to compare the differences between other ribosomal genes and high expression of high translation ribosomal genes. 
h2RIBO = df[df$ribo_TPM > qRIBO[90],]    # Top 10%
m1RIBO = df[df$ribo_TPM < qRIBO[45],]    # Bottom 45%
m2RIBO = df[df$ribo_TPM < qRIBO[55],]   # Bottom 55%
lRIBO = df[df$ribo_TPM < qRIBO[10],]     # BOTTOM 10%
mRIBO = subset(m2RIBO,!m2RIBO$ribo_TPM %in%c(m1RIBO$ribo_TPM)) # Middle 10%

hE_hT <- merge(hiRNA,hiRIBO,all = F)  #TOP5% mRNA level and top3% RIBOseq level,intersection.
hE_hT10 <- merge(h2RNA,h2RIBO,all = F) 
lE_lT <- merge(lRNA,lRIBO,all = F)
mE_mT <- merge(mRNA,mRIBO,all = F)
#ehE_hT <- subset(x = df,subset = TPM>10^3 & ribo_TPM>10^3,select = c(Gene_name,TPM,ribo_TPM))
#hE_hT <- subset(x = df,subset = TPM>10^3 & ribo_TPM>55,select = c(Gene_name,TPM,ribo_TPM))
#lE_lT <- subset(x =df,subset = TPM<.3 & ribo_TPM<.3,select = c(Gene_name,TPM,ribo_TPM))
#write.table(hE_hT_def,file = paste0("./ribo_num/",name,"_hE_ht_def_gene.txt"),sep = "\t",quote = FALSE,
#            row.names = F)
#write.table(lE_lT_def,paste0("./ribo_num/",name,"_lE_lT_def_gene.txt"),sep = "\t",quote = FALSE,
#            row.names = F)
write.table(other_ribo,file = paste0("./ribo_num/",name,"_other_ribo_gene.txt"),sep = "\t",quote = FALSE,
            row.names = F)
#write.table(ehE_hT,file = paste0("./ribo_num/",name,"_ehiE_ht_gene.txt"),sep = "\t",quote = FALSE,
#            row.names = F)
#write.table(hE_hT,file = paste0("./ribo_num/",name,"_hiE_ht_gene.txt"),sep = "\t",quote = FALSE,
#            row.names = F)
write.table(lE_lT$Gene_ID,file = paste0("./ribo_num/",name,"_lE_lT_only_geneID.txt"),sep = "\t",quote = FALSE,
            row.names = F )
write.table(hE_hT$Gene_ID,file = paste0("./ribo_num/",name,"_hE_hT_only_geneID.txt"),sep = "\t",quote = FALSE,
            row.names = F,col.names = F)
write.table(hE_hT10$Gene_ID,file = paste0("./ribo_num/",name,"_hE_hT10_only_geneID.txt"),sep = "\t",quote = FALSE,
            row.names = F,col.names = F)
write.table(mE_mT$Gene_ID,file = paste0("./ribo_num/",name,"_mE_mT10_only_geneID.txt"),sep = "\t",quote = FALSE,
            row.names = F,col.names = F)
rp = df[grep("^rpl|^rps",ignore.case = T,df$Gene_name),]
all_rp = df[grep("rpl|rps",ignore.case = T,df$Gene_name),]
mrp = all_rp[-grep("^rpl|^rps",ignore.case = T,all_rp$Gene_name),]
write.table(rp$Gene_ID,file = paste0("./ribo_num/",name,"_rp_only_geneID.txt"),sep = "\t",quote = FALSE,
            row.names = F,col.names = F)
write.table(mrp$Gene_ID,file = paste0("./ribo_num/",name,"_Mrp_only_geneID.txt"),sep = "\t",quote = FALSE,
            row.names = F,col.names = F)
write.table(all_rp$Gene_ID,file = paste0("./ribo_num/",name,"_all_rp_only_geneID.txt"),sep = "\t",quote = FALSE,
            row.names = F,col.names = F)
#======================================================================================================
# GO and KEGG analyze high translation efficiency genes,high RNA level & high translation level genes,
# low RNA level & low translation level genes.
#======================================================================================================
library(topGO)
library(clusterProfiler)
library(pathview)
library(AnnotationHub)
require(AnnotationHub)
hub = AnnotationHub()
unique(hub$species)
hub$species[which(hub$species== KEGG_spe)]
query(hub,KEGG_spe)
hub[hub$species ==  KEGG_spe &hub$rdataclass == 'OrgDb']
OrgDb = hub[["AH70579"]]
keytypes(OrgDb)
#columns(OrgDb)
#==============================================================================================
# Import data and conversion id
#==============================================================================================
##high translation efficiency genes conversion id 
hiTE_symbol_id =  hiTE$Gene.Name     
hiTE_symbol_id = as.character(hiTE_symbol_id)                    
hiTE_entrez_id = bitr(hiTE_symbol_id, 'GENENAME','ENTREZID',OrgDb)
head(hiTE_entrez_id,2)
write.table(hiTE_entrez_id,file = paste0(name,"_hiTE_sym_entrez.txt"),sep = '\t',quote = FALSE,
            row.names = FALSE)
TE_only_entrezID = hiTE_entrez_id[-1]
write.table(TE_only_entrezID,file = paste0(name,"_hiTE_ENTREZID.txt"),sep = '\t',quote = FALSE,
            row.names = FALSE)
##extreme high RNA expression level and high translation level genes
ehE_hT_symID = ehE_hT$Gene_name
ehE_hT_symID = as.character(ehE_hT_symID)
ehE_hT_entID = bitr(ehE_hT_symID,'GENENAME','ENTREZID',OrgDb)
head(ehE_hT_entID,2)
write.table(ehE_hT_entID,file = paste0(name,"_ehE_hT_sym_entrez.txt"),sep = '\t',quote = F,row.names = F)
ehET_only_entID = ehE_hT_entID[-1]
write.table(ehET_only_entID,file = paste0(name,"_ehET_ENTREZID.txt"),sep = '\t',quote = F,row.names = F)
## high RNA expression level and high translation level genes
hE_hT_symID = hE_hT$Gene_name
hE_hT_symID = as.character(hE_hT_symID)
hE_hT_entID = bitr(hE_hT_symID,'GENENAME','ENTREZID',OrgDb)
head(hE_hT_entID,2)
write.table(hE_hT_entID,file = paste0(name,"_hE_hT_sym_entrez.txt"),sep = '\t',quote = F,row.names = F)
hET_only_entID = hE_hT_entID[-1]
write.table(hET_only_entID,file = paste0(name,"_hET_ENTREZID.txt"),sep = '\t',quote = F,row.names = F)
## low RNA expression level and low translation level genes
lE_lT_symID = lE_lT$Gene_name
lE_lT_symID = as.character(lE_lT_symID)
lE_lT_entID = bitr(lE_lT_symID,'GENENAME','ENTREZID',OrgDb)
head(lE_lT_entID,2)
write.table(lE_lT_entID,file = paste0(name,"_lE_lT_sym_entrez.txt"),sep = '\t',quote = F,row.names = F)
hET_only_entID = lE_lT_entID[-1]
write.table(hET_only_entID,file = paste0(name,"_lET_ENTREZID.txt"),sep = '\t',quote = F,row.names = F)
#==============================================================================================
# GO analysis ORA(over-representation analysis)
#==============================================================================================
#**************all(Biological Process,Cellular Component,Molecular Function)*******************
if(FALSE) {                             # something wrong,modify it later
  GO_all <- function(x,y)     {
    go_all = enrichGO(
      gene = y, 
      keyType = "ENTREZID",
      OrgDb = OrgDb,        
      ont = "ALL",                    # Can also be a kind of CC,BP,MF
      pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
      pvalueCutoff = 0.05,            
      qvalueCutoff = 0.2,
      readable = TRUE)                # ID to GENENAME,easy to read
    #head(paste0(go_all,2))
    write.table(go_all,file = paste0(name,"_",x,"_aLL_enrich.txt"),row.names =FALSE)
    svg(filename = paste0(name,"_",x,"_ALLdot.svg"))
    dotplot(go_all, x = "Count", title = "EnrichmentGO_all_dot")
    dev.off()
    png("test.png")
    #svg(filename = paste0(name,"_",x,"_ALLbar.svg"))
    barplot(go_all,showCategory = 10,title = "EnrichmentGO_all_bar")
    dev.off()
  }
  GO_all("hiTE",hiTE_entrez_id$ENTREZID)  ## high TE
}
## high TE
hiTE_go_all = enrichGO(
  gene = hiTE_entrez_id$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "ALL",                    # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 1,            
  qvalueCutoff = 1,
  readable = F)                # ID to GENENAME,easy to read
head(hiTE_go_all,2)
write.table(hiTE_go_all,file = paste0(name,"_hiTE_aLL_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_hiTE_ALLdot.svg"))
dotplot(hiTE_go_all,title = "EnrichmentGO_all_dot")
dev.off()
svg(filename = paste0(name,"_hiTE_ALLbar.svg"))
barplot(hiTE_go_all,showCategory = 10,title = "EnrichmentGO_all_bar")
dev.off()
## extreme high RNA expression level and high translation level genes
ehE_hT_go_all = enrichGO(
  gene = ehE_hT_entID$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "ALL",                    # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 0.05,            
  qvalueCutoff = 0.2,
  readable = F)                # ID to GENENAME,easy to read
head(ehE_hT_go_all,2)
write.table(ehE_hT_go_all,file = paste0(name,"_ehE_hT_aLL_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_ehE_hT_ALLdot.svg"))
dotplot(ehE_hT_go_all,title = "EnrichmentGO_all_dot")
dev.off()
svg(filename = paste0(name,"_ehE_hT_ALLbar.svg"))
barplot(ehE_hT_go_all,showCategory = 10,title = "EnrichmentGO_all_bar")
dev.off()
## high RNA expression level and high translation level genes
hE_hT_go_all = enrichGO(
  gene = hE_hT_entID$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "ALL",                    # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 0.05,            
  qvalueCutoff = 0.2,
  readable = F)                # ID to GENENAME,easy to read
head(hE_hT_go_all,2)
write.table(hE_hT_go_all,file = paste0(name,"_hE_hT_aLL_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_hE_hT_ALLdot.svg"))
dotplot(hE_hT_go_all,title = "EnrichmentGO_all_dot")
dev.off()
svg(filename = paste0(name,"_hE_hT_ALLbar.svg"))
barplot(hE_hT_go_all,showCategory = 10,title = "EnrichmentGO_all_bar")
dev.off()
## low RNA expression level and low translation level genes
lE_lT_go_all = enrichGO(
  gene = lE_lT_entID$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "ALL",                    # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 0.05,            
  qvalueCutoff = 0.2,
  readable = F)                # ID to GENENAME,easy to read
head(lE_lT_go_all,2)
write.table(lE_lT_go_all,file = paste0(name,"_lE_lT_aLL_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_lE_lT_ALLdot.svg"))
dotplot(lE_lT_go_all,title = "EnrichmentGO_all_dot")
dev.off()
svg(filename = paste0(name,"_lE_lT_ALLbar.svg"))
barplot(lE_lT_go_all,showCategory = 10,title = "EnrichmentGO_all_bar")
dev.off()
#*********************************** MF(Molecular Function)*************************************
## high TE
hiTE_go_MF = enrichGO(
  gene = hiTE_entrez_id$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "MF",                    # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 1,            
  qvalueCutoff = 1,
  readable = F) 
head(hiTE_go_MF)
write.table(hiTE_go_MF,file = paste0(name,"_hiTE_MF_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_hiTE_MFdot.svg"))
dotplot(hiTE_go_MF,title = "EnrichmentGO_MF_dot")
dev.off()
svg(filename = paste0(name,"_hiTE_MFbar.svg"))
barplot(hiTE_go_MF,showCategory = 10,title = "EnrichmentGO_MF_bar")
dev.off()
#plotGOgraph(hiTE_go_MF)
#.rs.restartR()                    # if occur error 
svg(filename = paste0(name,"_hiTE_MFgoplot.svg"))
goplot(hiTE_go_MF)
dev.off()
#emapplot(hiTE_go_MF,showCategory = 30)
#cnetplot(hiTE_go_MF,showCategory = 5)
## extreme high RNA expression level and high translation level genes
ehE_hT_go_MF = enrichGO(
  gene = ehE_hT_entID$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "MF",                    # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 0.05,            
  qvalueCutoff = 0.2,
  readable = F) 
head(ehE_hT_go_MF)
write.table(ehE_hT_go_MF,file = paste0(name,"_ehE_hT_MF_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_ehE_hT_MFdot.svg"))
dotplot(ehE_hT_go_MF,title = "EnrichmentGO_MF_dot")
dev.off()
svg(filename = paste0(name,"_ehE_hT_MFbar.svg"))
barplot(ehE_hT_go_MF,showCategory = 10,title = "EnrichmentGO_MF_bar")
dev.off()
#plotGOgraph(ehE_hT_go_MF)
#.rs.restartR()                    # if occur error 
svg(filename = paste0(name,"_ehE_hT_MFgoplot.svg"))
goplot(ehE_hT_go_MF)
dev.off()
## high RNA expression level and high translation level genes
hE_hT_go_MF = enrichGO(
  gene = hE_hT_entID$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "MF",                    # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 0.05,            
  qvalueCutoff = 0.2,
  readable = F) 
head(hE_hT_go_MF)
write.table(hE_hT_go_MF,file = paste0(name,"_hE_hT_MF_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_hE_hT_MFdot.svg"))
dotplot(hE_hT_go_MF,title = "EnrichmentGO_MF_dot")
dev.off()
svg(filename = paste0(name,"_hE_hT_MFbar.svg"))
barplot(hE_hT_go_MF,showCategory = 10,title = "EnrichmentGO_MF_bar")
dev.off()
#plotGOgraph(hE_hT_go_MF)
#.rs.restartR()                    # if occur error 
svg(filename = paste0(name,"_hE_hT_MFgoplot.svg"))
goplot(hE_hT_go_MF)
dev.off()
## low RNA expression level and low translation level genes
lE_lT_go_MF = enrichGO(
  gene = lE_lT_entID$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "MF",                    # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 1,            
  qvalueCutoff = 1,
  readable = F) 
head(lE_lT_go_MF)
write.table(lE_lT_go_MF,file = paste0(name,"_lE_lT_MF_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_lE_lT_MFdot.svg"))
dotplot(lE_lT_go_MF,title = "EnrichmentGO_MF_dot")
dev.off()
svg(filename = paste0(name,"_lE_lT_MFbar.svg"))
barplot(lE_lT_go_MF,showCategory = 10,title = "EnrichmentGO_MF_bar")
dev.off()
#plotGOgraph(lE_lT_go_MF)
#.rs.restartR()                    # if occur error 
svg(filename = paste0(name,"_lE_lT_MFgoplot.svg"))
goplot(lE_lT_go_MF)
dev.off()
#********************************BP(Biological Process)*******************************
## high TE
hiTE_go_BP = enrichGO(
  gene = hiTE_entrez_id$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "BP",                    # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 1,            
  qvalueCutoff = 1,
  readable = F) 
head(hiTE_go_BP)
write.table(hiTE_go_BP,file = paste0(name,"_hiTE_BP_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_hiTE_BPdot.svg"))
dotplot(hiTE_go_BP,title = "EnrichGO_BP_dot")
dev.off()
svg(filename = paste0(name,"_hiTE_BPbar.svg"))
barplot(hiTE_go_BP,showCategory = 10,title = "EnrichmentGO_BP_bar")
dev.off()
#plotGOgraph(hiTE_go_BP)
#.rs.restartR()                    # if occur error 
svg(filename = paste0(name,"_hiTE_BPgoplot.svg"))
goplot(hiTE_go_BP)
dev.off()
#emapplot(hiTE_go_BP,showCategory = 30)
#cnetplot(hiTE_go_BP,showCategory = 5)
## extreme high
ehE_hT_go_BP = enrichGO(
  gene = ehE_hT_entID$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "BP",                    # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 0.05,            
  qvalueCutoff = 0.2,
  readable = F) 
head(ehE_hT_go_BP)
write.table(ehE_hT_go_BP,file = paste0(name,"_ehE_hT_BP_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_ehE_hT_BPdot.svg"))
dotplot(ehE_hT_go_BP,title = "EnrichGO_BP_dot")
dev.off()
svg(filename = paste0(name,"_ehE_hT_BPbar.svg"))
barplot(ehE_hT_go_BP,showCategory = 10,title = "EnrichmentGO_BP_bar")
dev.off()
#plotGOgraph(ehE_hT_go_BP)
#.rs.restartR()                    # if occur error 
svg(filename = paste0(name,"_ehE_hT_BPgoplot.svg"))
goplot(ehE_hT_go_BP)
dev.off()
## high expression and high translation
hE_hT_go_BP = enrichGO(
  gene = hE_hT_entID$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "BP",                    # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 0.05,            
  qvalueCutoff = 0.2,
  readable = F) 
head(hE_hT_go_BP)
write.table(hE_hT_go_BP,file = paste0(name,"_hE_hT_BP_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_hE_hT_BPdot.svg"))
dotplot(hE_hT_go_BP,title = "EnrichGO_BP_dot")
dev.off()
svg(filename = paste0(name,"_hE_hT_BPbar.svg"))
barplot(hE_hT_go_BP,showCategory = 10,title = "EnrichmentGO_BP_bar")
dev.off()
#plotGOgraph(hE_hT_go_BP)
#.rs.restartR()                    # if occur error 
svg(filename = paste0(name,"_hE_hT_BPgoplot.svg"))
goplot(hE_hT_go_BP)
dev.off()
## low expression and low translation
lE_lT_go_BP = enrichGO(
  gene = lE_lT_entID$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "BP",                    # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 0.05,            
  qvalueCutoff = 0.2,
  readable = F) 
head(lE_lT_go_BP)
write.table(lE_lT_go_BP,file = paste0(name,"_lE_lT_BP_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_lE_lT_BPdot.svg"))
dotplot(lE_lT_go_BP,title = "EnrichGO_BP_dot")
dev.off()
svg(filename = paste0(name,"_lE_lT_BPbar.svg"))
barplot(lE_lT_go_BP,showCategory = 10,title = "EnrichmentGO_BP_bar")
dev.off()
#plotGOgraph(lE_lT_go_BP)
#.rs.restartR()                    # if occur error 
svg(filename = paste0(name,"_lE_lT_BPgoplot.svg"))
goplot(lE_lT_go_BP)
dev.off()
#********************************CC(Cellular Component)*******************************
## high TE
hiTE_go_CC = enrichGO(
  gene = hiTE_entrez_id$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "CC",                     # Can also be a kind of CC,BP,MF
  pAdjustMethod = "BH",           # other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 1,            
  qvalueCutoff = 1,
  readable = F) 
head(hiTE_go_CC)
write.table(hiTE_go_CC,paste0(name,"_hiTE_CC_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_hiTE_CCdot.svg"))
dotplot(hiTE_go_CC,title = "EnrichmentGO_CC_dot")
dev.off()
svg(filename = paste0(name,"_hiTE_CCbar.svg"))
barplot(hiTE_go_CC,showCategory = 10,title = "EnrichmentGO_CC_bar")
dev.off()
#plotGOgraph(hiTE_go_CC)
#.rs.restartR()                    # if occur error 
svg(filename = paste0(name,"_hiTE_CCgoplot.svg"))
goplot(hiTE_go_CC)
dev.off()
#emapplot(hiTE_go_CC,showCategory = 30)
#cnetplot(hiTE_go_CC,showCategory = 5)
## extreme high
ehE_hT_go_CC = enrichGO(
  gene = ehE_hT_entID$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "CC",                    # Can also be a kind of CC,CC,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 0.05,            
  qvalueCutoff = 0.2,
  readable = F) 
head(ehE_hT_go_CC)
write.table(ehE_hT_go_CC,file = paste0(name,"_ehE_hT_CC_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_ehE_hT_CCdot.svg"))
dotplot(ehE_hT_go_CC,title = "EnrichGO_CC_dot")
dev.off()
svg(filename = paste0(name,"_ehE_hT_CCbar.svg"))
barplot(ehE_hT_go_CC,showCategory = 10,title = "EnrichmentGO_CC_bar")
dev.off()
#plotGOgraph(ehE_hT_go_CC)
#.rs.restartR()                    # if occur error 
svg(filename = paste0(name,"_ehE_hT_CCgoplot.svg"))
goplot(ehE_hT_go_CC)
dev.off()
## high expression and high translation
hE_hT_go_CC = enrichGO(
  gene = hE_hT_entID$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "CC",                    # Can also be a kind of CC,CC,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 0.05,            
  qvalueCutoff = 0.2,
  readable = F) 
head(hE_hT_go_CC)
write.table(hE_hT_go_CC,file = paste0(name,"_hE_hT_CC_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_hE_hT_CCdot.svg"))
dotplot(hE_hT_go_CC,title = "EnrichGO_CC_dot")
dev.off()
svg(filename = paste0(name,"_hE_hT_CCbar.svg"))
barplot(hE_hT_go_CC,showCategory = 10,title = "EnrichmentGO_CC_bar")
dev.off()
#plotGOgraph(hE_hT_go_CC)
#.rs.restartR()                    # if occur error 
svg(filename = paste0(name,"_hE_hT_CCgoplot.svg"))
goplot(hE_hT_go_CC)
dev.off()
## low expression and low translation
lE_lT_go_CC = enrichGO(
  gene = lE_lT_entID$ENTREZID, 
  keyType = "ENTREZID",
  OrgDb = OrgDb,        
  ont = "CC",                    # Can also be a kind of CC,CC,MF
  pAdjustMethod = "BH",           #other correction methods: holm,hochberg,hommel,bonferroni,BH,BY,fdr,none
  pvalueCutoff = 0.05,            
  qvalueCutoff = 0.2,
  readable = F) 
head(lE_lT_go_CC)
write.table(lE_lT_go_CC,file = paste0(name,"_lE_lT_CC_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_lE_lT_CCdot.svg"))
dotplot(lE_lT_go_CC,title = "EnrichGO_CC_dot")
dev.off()
svg(filename = paste0(name,"_lE_lT_CCbar.svg"))
barplot(lE_lT_go_CC,showCategory = 10,title = "EnrichmentGO_CC_bar")
dev.off()
#plotGOgraph(lE_lT_go_CC)
#.rs.restartR()                    # if occur error 
svg(filename = paste0(name,"_lE_lT_CCgoplot.svg"))
goplot(lE_lT_go_CC)
dev.off()
#=====================================================================================
# KEGG analysis
#=====================================================================================
## high TE 
hiTE_KEGG_id = bitr_kegg(
  hiTE_entrez_id$ENTREZID,
  fromType = "ncbi-geneid",
  toType = 'kegg',
  organism='sce')           #abbreviation https://www.genome.jp/kegg/catalog/org_list.html
head(hiTE_KEGG_id)
write.table(hiTE_KEGG_id,file = paste0(name,"_hiTE_KEGGid.txt"),sep = '\t',quote = FALSE,
            row.names = FALSE)
hiTE_ke = enrichKEGG(
  gene = hiTE_KEGG_id$kegg,
  keyType = "kegg", 
  organism = 'sce',         
  pAdjustMethod = "BH", 
  pvalueCutoff = 1, 
  qvalueCutoff = 1 )
head(hiTE_ke)
write.table(hiTE_ke,paste0(name,"_hiTE_KEGG_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_hiTE_KEGGdot.svg"))
dotplot(hiTE_ke,showCategory = 10,title="KEGG_dot")
dev.off()
svg(filename = paste0(name,"_hiTE_KEGGbar.svg"))
barplot(hiTE_ke,showCategory = 10,title="KEGG_bar")
dev.off()
#.rs.restartR()                    # if occur error 
emapplot(hiTE_ke,showCategory = 30)
cnetplot(hiTE_ke,showCategory = 5)
#browseKEGG(ke, "keggid")          # Mark enriched genes on the pathway map
## extreme high RNA expression level and high translation level genes
ehE_hT_KEGG_id = bitr_kegg(
  ehE_hT_entID$ENTREZID,
  fromType = "ncbi-geneid",
  toType = 'kegg',
  organism='sce')           #abbreviation https://www.genome.jp/kegg/catalog/org_list.html
head(ehE_hT_KEGG_id)
write.table(ehE_hT_KEGG_id,file = paste0(name,"_ehE_hT_KEGGid.txt"),sep = '\t',quote = FALSE,
            row.names = FALSE)
ehE_hT_ke = enrichKEGG(
  gene = ehE_hT_KEGG_id$kegg,
  keyType = "kegg", 
  organism = 'sce',         
  pAdjustMethod = "BH", 
  pvalueCutoff = 1, 
  qvalueCutoff = 1 )
head(ehE_hT_ke)
write.table(ehE_hT_ke,paste0(name,"_ehE_hT_KEGG_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_ehE_hT_KEGGdot.svg"))
dotplot(ehE_hT_ke,showCategory = 10,title="KEGG_dot")
dev.off()
svg(filename = paste0(name,"_ehE_hT_KEGGbar.svg"))
barplot(ehE_hT_ke,showCategory = 10,title="KEGG_bar")
dev.off()
#.rs.restartR()                    # if occur error 
emapplot(ehE_hT_ke,showCategory = 30)
cnetplot(ehE_hT_ke,showCategory = 5)
## high RNA expression level and high translation level genes
hE_hT_KEGG_id = bitr_kegg(
  hE_hT_entID$ENTREZID,
  fromType = "ncbi-geneid",
  toType = 'kegg',
  organism='sce')           #abbreviation https://www.genome.jp/kegg/catalog/org_list.html
head(hE_hT_KEGG_id)
write.table(hE_hT_KEGG_id,file = paste0(name,"_hE_hT_KEGGid.txt"),sep = '\t',quote = FALSE,
            row.names = FALSE)
hE_hT_ke = enrichKEGG(
  gene = hE_hT_KEGG_id$kegg,
  keyType = "kegg", 
  organism = 'sce',         
  pAdjustMethod = "BH", 
  pvalueCutoff = 1, 
  qvalueCutoff = 1 )
head(hE_hT_ke)
write.table(hE_hT_ke,paste0(name,"_hE_hT_KEGG_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_hE_hT_KEGGdot.svg"))
dotplot(hE_hT_ke,showCategory = 10,title="KEGG_dot")
dev.off()
svg(filename = paste0(name,"_hE_hT_KEGGbar.svg"))
barplot(hE_hT_ke,showCategory = 10,title="KEGG_bar")
dev.off()
#.rs.restartR()                    # if occur error 
emapplot(hE_hT_ke,showCategory = 30)
cnetplot(hE_hT_ke,showCategory = 5)
## low RNA expression level and low translation level genes
lE_lT_KEGG_id = bitr_kegg(
  lE_lT_entID$ENTREZID,
  fromType = "ncbi-geneid",
  toType = 'kegg',
  organism='sce')           #abbreviation https://www.genome.jp/kegg/catalog/org_list.html
head(lE_lT_KEGG_id)
write.table(lE_lT_KEGG_id,file = paste0(name,"_lE_lT_KEGGid.txt"),sep = '\t',quote = FALSE,
            row.names = FALSE)
lE_lT_ke = enrichKEGG(
  gene = lE_lT_KEGG_id$kegg,
  keyType = "kegg", 
  organism = 'sce',         
  pAdjustMethod = "BH", 
  pvalueCutoff = 1, 
  qvalueCutoff = 1 )
head(lE_lT_ke)
write.table(lE_lT_ke,paste0(name,"_lE_lT_KEGG_enrich.txt"),row.names =FALSE)
svg(filename = paste0(name,"_lE_lT_KEGGdot.svg"))
dotplot(lE_lT_ke,showCategory = 10,title="KEGG_dot")
dev.off()
svg(filename = paste0(name,"_lE_lT_KEGGbar.svg"))
barplot(lE_lT_ke,showCategory = 10,title="KEGG_bar")
dev.off()
#.rs.restartR()                    # if occur error 
emapplot(lE_lT_ke,showCategory = 30)
cnetplot(lE_lT_ke,showCategory = 5)
