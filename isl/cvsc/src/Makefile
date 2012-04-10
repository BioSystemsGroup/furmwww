ifeq ($(SWARMHOME),)
SWARMHOME=/usr
endif
ifeq ($(MPIHOME),)
#MPIHOME=/opt/mpich-ch_p4-gcc-1.2.7
MPIHOME=/usr/lib/mpich
endif
APPLICATION=liver
APPVERSION=2002-11-27
BUGADDRESS=gepr@tempusdictum.com
MODELUTILS=../../modelUtils
include $(MODELUTILS)/Makefile.utl

# ISL core module
OBJECTS=CommandLineOptionHandler.o RootSwarm.o RootObject.o \
	ExperAgent.o \
	ParameterManager.o \
	BatchAnalyzer.o \
	LiverDMM.o LiverGML.o \
	DatModel.o HDFDatModel.o CSVDatModel.o \
	ArtModel.o \
	artModel/LiverNode.o artModel/Sinusoid.o artModel/Vas.o artModel/PVT.o \
	artModel/LiverLink.o artModel/FlowLink.o artModel/SpatialLink.o \
	artModel/Particle.o artModel/Solute.o artModel/Enzyme.o \
	artModel/SoluteTag.o \
	artModel/SerialInjection.o \
	artModel/Binder.o \
	artModel/Cell.o artModel/ECell.o artModel/Hepatocyte.o \
	artModel/FlowSpace.o artModel/MiddleSpace.o \
	artModel/FlowTube.o artModel/BileCanal.o \
	artModel/SinusoidalSpace.o artModel/DisseSpace.o \
	artModel/ESpace.o \
	artModel/VasGraph.o artModel/LobuleSpec.o \
	RefModel.o \
	refModel/liver_model.o refModel/ConvectionDispersion.o \
	refModel/ExtendedConvectionDispersion.o \
	$(UTILOBJECTS)

# Parallel module
POBJECTS=parallel/Parallelism.o parallel/Partitioner.o  \
	parallel/Handler.o  \
	parallel/OperationBuilder.o \
	ParallelCLOH.o ParallelEA.o

# Optimization module
OOBJECTS=optimization/ParameterGenerator.o \
	optimization/ParameterSweeper.o

# environment for MPI
ifeq ($(parallel),yes)
PARALLEL= yes
MAIN=pisl.o
else
PARALLEL= no
MAIN=isl.o
endif

MPIINCLUDES= -I$(MPIHOME)/include
MPILIBS= -L$(MPIHOME)/lib -lmpich

OTHERCLEAN = *~ parallel/*~ parallel/*.o optimization/*~ optimization/*.o monitors/* debugs/* outputs/* artModel/*~ refModel/*~ $(MODELUTILS)/*~ datModel/*~ inputs/*~  

OTHERCLEAN1 = *~ parallel/*~ parallel/*.o optimization/*~ optimization/*.o monitors/* debugs/* artModel/*~ refModel/*~ $(MODELUTILS)/*~ datModel/*~ inputs/*~  

# DATAFILES = liver.scm

EXTRAOBJCFLAGS=-Wno-error -DUSE_LISP
#EXTRAOBJCFLAGS=-Werror

# specify profile=yes on the make command line to enable profiling
ifeq ($(profile),yes)
PROFFLAGS = -pg
endif

#include gd graphics library
APPLIBS= -lgd

include $(SWARMHOME)/etc/swarm/Makefile.appl

SAVEDIR:=$(shell date +"%F-%H%M")

save:
	mkdir $(SAVEDIR)
	cp -fr outputs $(SAVEDIR)/outputs
	cp -fr inputs  $(SAVEDIR)/inputs
	cp -fr monitors $(SAVEDIR)/monitors
	gzip -9 $(SAVEDIR)/monitors/monitor*
	cp -fr debugs $(SAVEDIR)/debugs
	gzip -9 $(SAVEDIR)/debugs/debug*
	if test -f nohup.out; then cp nohup.out $(SAVEDIR)/; fi

runclean:
	-rm -rf outputs/* monitors/* debugs/* inputs/parameters/*-SEQ
	if test -f nohup.out; then rm -rf nohup.out; fi

clean: runclean
	-rm -rf $(MAIN) $(OBJECTS) $(POBJECTS) $(OOBJECTS) $(APPEXE) .libs/$(APPEXE) .libs/lt-$(APPEXE) $(OTHERCLEAN1) core gmon.out $(APPEXE).core dosage_test

.m.o:
ifeq ($(PARALLEL),yes)
	$(OBJC) -o $*.o -c $(PROFFLAGS) -D__PARALLEL__ $(OBJCFLAGS) $(CPPFLAGS) $(DLLCPPFLAGS) $(EXTRACPPFLAGS) $(SWARMINCLUDES) $(MPIINCLUDES) -I$(MODELUTILS) $< 
else
	$(OBJC) -o $*.o -c $(PROFFLAGS) $(OBJCFLAGS) $(CPPFLAGS) $(DLLCPPFLAGS) $(EXTRACPPFLAGS) $(SWARMINCLUDES) -I$(MODELUTILS) $< 
endif

.c.o:
ifeq ($(PARALLEL), yes)
	$(OBJC) -o $*.o -c $(PROFFLAGS) -D__PARALLEL__ $(CFLAGS) $(CPPFLAGS) $(DLLCPPFLAGS) $(EXTRACPPFLAGS) $(SWARMINCLUDES) $(MPIINCLUDES) -I$(MODELUTILS) $<
else
	$(OBJC) -o $*.o -c $(PROFFLAGS) $(CFLAGS) $(CPPFLAGS) $(DLLCPPFLAGS) $(EXTRACPPFLAGS) $(SWARMINCLUDES) -I$(MODELUTILS) $< 
endif

ifeq ($(PARALLEL),yes)

$(APPEXE): $(MAIN) $(OBJECTS) $(POBJECTS) $(OOBJECTS)
	$(SHELL) $(bindir)/libtool-swarm --mode link g++ $(PROFFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $(MAIN) $(OBJECTS) $(POBJECTS) $(OOBJECTS) $(APPLIBS) $(SWARMLIBS) $(OBJCLIBS) $(EXTRALIBS) $(MPILIBS)
else 
$(APPEXE): $(MAIN) $(OBJECTS) $(OOBJECTS)
	$(SHELL) $(bindir)/libtool-swarm --mode link g++ $(PROFFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $(MAIN) $(OBJECTS) $(OOBJECTS) $(APPLIBS) $(SWARMLIBS) $(OBJCLIBS) $(EXTRALIBS)
endif

dosage_test: $(UTILOBJECTS)
	$(OBJC) -o artModel/SerialInjection.o -c $(PROFFLAGS) -DTESTING $(CFLAGS) $(CPPFLAGS) $(DLLCPPFLAGS) $(EXTRACPPFLAGS) $(SWARMINCLUDES) $(MPIINCLUDES) -I$(MODELUTILS) artModel/SerialInjection.m
	$(SHELL) $(bindir)/libtool-swarm --mode link g++ $(PROFFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ artModel/SerialInjection.o $? $(APPLIBS) $(SWARMLIBS) $(OBJCLIBS) $(EXTRALIBS)

liver_model: refModel/liver_model.o refModel/Model.h refModel/ConvectionDispersion.o refModel/ExtendedConvectionDispersion.o
	$(CC) $(PROFFLAGS) -g -o refModel/liver_model refModel/liver_model.o refModel/ConvectionDispersion.o refModel/ExtendedConvectionDispersion.o -I./refModel

refModel/liver_model.o: refModel/liver_model.cc
	$(CC) $(PROFFLAGS) -g -o $@ -c refModel/liver_model.cc -I./refModel

refModel/ConvectionDispersion.o: refModel/Model.h refModel/ConvectionDispersion.cc refModel/ConvectionDispersion.h
	$(CC) $(PROFFLAGS) -g -o $@ -c refModel/ConvectionDispersion.cc -I./refModel

refModel/ExtendedConvectionDispersion.o: refModel/Model.h refModel/ExtendedConvectionDispersion.cc refModel/ExtendedConvectionDispersion.h	
	g++ $(PROFFLAGS) -g -o $@ -c refModel/ExtendedConvectionDispersion.cc -I./refModel

isl.o: isl.m *.h 
pisl.o: pisl.m *.h 
CommandLineOptionHandler.o: CommandLineOptionHandler.[hm] 
ParallelCLOH.o: ParallelCLOH.[hm] CommandLineOptionHandler.h
RootSwarm.o: RootSwarm.[hm]
RootObject.o: RootObject.[hm]
BatchAnalyzer.o: BatchAnalyzer.[hm]
ArtModel.o: $(MODELUTILS)/dosage.h $(MODELUTILS)/DMM.h ArtModel.[hm]
DatModel.o: DatModel.[hm]
HDFDatModel.o: HDFDatModel.[hm] DatModel.[hm]
CSVDatModel.o: CSVDatModel.[hm] DatModel.[hm]
RefModel.o: RefModel.[hm]
ExperAgent.o: ExperAgent.[hm] DatModel.h ArtModel.h RefModel.h
ParallelEA.o: ParallelEA.[hm] ExperAgent.h DatModel.h ArtModel.h RefModel.h
ParameterManager.o: ParameterManager.[hm] 
LiverDMM.o: LiverDMM.[hm] protocols.h
artModel/LiverNode.o: artModel/LiverNode.[hm]
artModel/Sinusoid.o: artModel/LiverNode.h artModel/Sinusoid.[hm]
artModel/Vas.o: artModel/LiverNode.h artModel/Vas.[hm]
artModel/PVT.o: RootObject.h artModel/Solute.h artModel/PVT.[hm]
artModel/LiverLink.o: $(MODELUTILS)/graph/graph.h $(MODELUTILS)/graph/DiGraphLink.h artModel/LiverLink.[hm]
artModel/FlowLink.o: artModel/LiverLink.h artModel/FlowLink.[hm]
artModel/SpatialLink.o: artModel/LiverLink.h artModel/SpatialLink.[hm]
artModel/Particle.o: artModel/Particle.[hm]
artModel/Solute.o: artModel/Particle.h artModel/Solute.[hm]
artModel/SoluteTag.o: artModel/SoluteTag.[hm] $(MODELUTILS)/Tag.h
artModel/SerialInjection.o: artModel/SerialInjection.[hm] $(MODELUTILS)/Dosage.[hm]
artModel/Binder.o: artModel/Particle.h artModel/Binder.[hm]
artModel/Enzyme.o: artModel/Binder.h artModel/Enzyme.[hm]
artModel/Cell.o: artModel/Cell.[hm] artModel/protocols.h $(MODELUTILS)/modelUtils.h
artModel/ECell.o: artModel/ECell.[hm] artModel/ESpace.h artModel/DisseSpace.h artModel/SinusoidalSpace.h $(MODELUTILS)/modelUtils.h $(MODELUTILS)/LocalRandom.h
artModel/Hepatocyte.o: artModel/Hepatocyte.[hm]
artModel/FlowSpace.o: $(MODELUTILS)/Vector.h artModel/Sinusoid.h artModel/FlowSpace.[hm]
artModel/FlowTube.o: artModel/FlowTube.[hm] RootObject.h
artModel/BileCanal.o: artModel/BileCanal.[hm] artModel/FlowTube.h
artModel/MiddleSpace.o: artModel/MiddleSpace.[hm] artModel/FlowSpace.h
artModel/ESpace.o: artModel/ESpace.[hm] artModel/FlowSpace.h
artModel/SinusoidalSpace.o: artModel/SinusoidalSpace.[hm] artModel/FlowSpace.h
artModel/DisseSpace.o: artModel/DisseSpace.[hm] artModel/FlowSpace.h
artModel/VasGraph.o: artModel/VasGraph.[hm]
artModel/LobuleSpec.o: artModel/LobuleSpec.[hm]
parallel/Parallelism.o: parallel/Parallelism.[hm]
parallel/Partitioner.o: parallel/Partitioner.[hm] parallel/OperationBuilder.[hm]
parallel/Handler.o: parallel/Handler.[hm]
parallel/OperationBuilder.o: parallel/OperationBuilder.[hm]
optimization/ParameterGenerator.o: optimization/ParameterGenerator.[hm]
optimization/ParameterSweeper.o: optimization/ParameterSweeper.[hm]
