/*
 * IPRL - GML interface object
 *
 * Copyright 2003-2005 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#include <stdio.h>
#include <stdlib.h>

#import "GML.h"
#import "graph/graph.h"

//#import "../artModel/Vas.h"
//#import "../artModel/Sinusoid.h"
//#import "../artModel/FlowLink.h"


extern id <Symbol> In, Out;

void print_keys (struct GML_list_elem* list)
{
  struct GML_list_elem *tmp = list;
  while (tmp) {
    [Telem monitorOut: 3 printf: "%s\n", tmp->key];
    tmp = tmp->next;
  }
}

@implementation GML

- (int) readGMLFile: (const char *) fileName
{
  int retVal=0;

  parserStat=(struct GML_stat*)[[self getZone] alloc: sizeof(struct GML_stat)];
  parserStat->key_list = NULL;
    
  FILE* file = fopen (fileName, "r");
  if (file == 0) printf ("\n No such file: %s", fileName);
  else {
    GML_init ();
    elemList = GML_parser (file, parserStat, 0);

    if (parserStat->err.err_num != GML_OK) {

      printf ("An error occured while reading line %d column %d of %s:\n", 
              parserStat->err.line, parserStat->err.column, fileName);
      retVal = -1;

      switch (parserStat->err.err_num) {
      case GML_UNEXPECTED:
        printf ("UNEXPECTED CHARACTER");
        break;
		    
      case GML_SYNTAX:
        printf ("SYNTAX ERROR"); 
        break;
		    
      case GML_PREMATURE_EOF:
        printf ("PREMATURE EOF IN STRING");
        break;
		    
      case GML_TOO_MANY_DIGITS:
        printf ("NUMBER WITH TOO MANY DIGITS");
        break;
		    
      case GML_OPEN_BRACKET:
        printf ("OPEN BRACKETS LEFT AT EOF");
        break;
		    
      case GML_TOO_MANY_BRACKETS:
        printf ("TOO MANY CLOSING BRACKETS");
        break;
		
      default:
        break;
      }
		
      printf ("\n");
    }      
  }
  return (retVal);
}

/*
 * element manipulators
 */
- (char *) getKey: (struct GML_pair *)gmlElem
{
  if (gmlElem != (struct GML_pair *)nil) return gmlElem->key;
  else return (char *)nil;
}
- (GML_value) getKind: (struct GML_pair *)gmlElem
{
  if (gmlElem != (struct GML_pair *)nil) return gmlElem->kind;
  else return -1;
}

// iterate through this elements children and find a string named "label"
- (const char *) getLabel: (struct GML_pair *) gmlElem
{
  struct GML_pair *tmp;
  const char *label = (const char *)nil;

  if (gmlElem == (struct GML_pair *)nil)
    raiseEvent(GMLError, "GML: nil element.\n");

  if ( (gmlElem->value.list == (struct GML_pair *)nil)
       || (gmlElem->kind != GML_LIST) )
    raiseEvent(GMLError, "GML: GML_pair is not a list.\n");

  tmp = gmlElem->value.list;
  while (tmp != (struct GML_pair *)nil) {
    const char *key = [self getKey: tmp];
    if (strcmp(key,"label") == 0) {
      label = tmp->value.string;
      break;
    }
    tmp = tmp->next;
  }
  return label;
}

- (int) getID: (struct GML_pair *) gmlElem
{
  struct GML_pair *tmp;
  int idnumber=-1;

  if (gmlElem == (struct GML_pair *)nil)
    raiseEvent(GMLError, "GML: nil element.\n");

  if ( (gmlElem->value.list == (struct GML_pair *)nil)
       || (gmlElem->kind != GML_LIST) )
    raiseEvent(GMLError, "GML: GML_pair is not a list.\n");

  tmp = gmlElem->value.list;
  while (tmp != (struct GML_pair *)nil) {
    const char *key = [self getKey: tmp];
    if (strcmp(key,"id") == 0) {
      idnumber = tmp->value.integer;
      break;
    }
    tmp = tmp->next;
  }

  return idnumber;
}

- (int) getSource: (struct GML_pair *) gmlEdge
{
  int source=-1;
  struct GML_pair *tmp;

  if (gmlEdge == (struct GML_pair *)nil)
    raiseEvent(GMLError, "GML: nil Edge.\n");

  if ( (gmlEdge->value.list == (struct GML_pair *)nil)
       || (gmlEdge->kind != GML_LIST) )
    raiseEvent(GMLError, "GML: GML_pair is not a list.\n");

  tmp = gmlEdge->value.list;
  while (tmp != (struct GML_pair *)nil) {
    const char *key = [self getKey: tmp];
    if (strcmp(key,"source") == 0) {
      source = tmp->value.integer;
      break;
    }
    tmp = tmp->next;
  }
  return source;
}
- (int) getTarget: (struct GML_pair *) gmlEdge
{
  int target=-1;
  struct GML_pair *tmp;

  if (gmlEdge == (struct GML_pair *)nil)
    raiseEvent(GMLError, "GML: nil Edge.\n");

  if ( (gmlEdge->value.list == (struct GML_pair *)nil)
       || (gmlEdge->kind != GML_LIST) )
    raiseEvent(GMLError, "GML: GML_pair is not a list.\n");

  tmp = gmlEdge->value.list;
  while (tmp != (struct GML_pair *)nil) {
    const char *key = [self getKey: tmp];
    if (strcmp(key,"target") == 0) {
      target = tmp->value.integer;
      break;
    }
    tmp = tmp->next;
  }
  return target;
}

/*
 * Wholesale functions
 */

- printElements
{

  if (parserStat->err.err_num == GML_OK) {
    GML_print_list (elemList, 0);
    [Telem monitorOut: 3 printf: "Keys are: \n"];
    print_keys (parserStat->key_list);
  }

  return self;
}

+ createBegin: aZone
{
  GML *obj; 
  obj = [super createBegin: aZone];
  obj->GMLError = [Error create: globalZone setName: "GMLError"];
  return obj;
}

- (void) drop
{
  GML_free_list(elemList, parserStat->key_list);
  [super drop];
}
@end
