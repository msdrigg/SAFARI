from scipy.stats import maxwell
import pygame
import pygame.color
from pygame.locals import *
import crystalgen
import basisgen
import particles
import numpy as np
import math
from PyQt5.QtWidgets import *

key_to_function = {
    pygame.K_LEFT:   (lambda x: x.translateAll([-10,0,0])),
    pygame.K_RIGHT:  (lambda x: x.translateAll([ 10,0,0])),
    pygame.K_DOWN:   (lambda x: x.translateAll([0, 10,0])),
    pygame.K_UP:     (lambda x: x.translateAll([0,-10,0])),
    pygame.K_EQUALS: (lambda x: x.scaleAll(1.25)),
    pygame.K_MINUS:  (lambda x: x.scaleAll( 0.8)),
    pygame.K_q:      (lambda x: x.rotateAll([ 0.0005,0,0])),
    pygame.K_w:      (lambda x: x.rotateAll([-0.0005,0,0])),
    pygame.K_a:      (lambda x: x.rotateAll([0, 0.0005,0])),
    pygame.K_s:      (lambda x: x.rotateAll([0,-0.0005,0])),
    pygame.K_z:      (lambda x: x.rotateAll([0,0, 0.0005])),
    pygame.K_x:      (lambda x: x.rotateAll([0,0,-0.0005]))}

class Points:
    def __init__(self):
        # These are the points that render on the screen
        self.points_render = np.zeros((0,4))
        self.points_other  = np.zeros((0,4))
        self.colour = (255,255,125)
        self.colour_other = (55,55,55)
        self.transform = np.array([[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]])
    
    def update(self, particles):
        r = particles.positions
        i = np.ones((len(r),1))

        self.points_other = np.hstack((particles.r0, i))
        self.points_render = np.hstack((r, i))

        trans = np.copy(self.transform)
        self.transform = np.array([[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]])
        self.applyTransform(trans)
        return
    
    def applyTransform(self, matrix):
        self.transform = np.dot(self.transform, matrix)
        self.points_render = np.dot(self.points_render,matrix)
        self.points_other = np.dot(self.points_other,matrix)
    
    def translate(self, dx=0, dy=0, dz=0):
        self.applyTransform(self.translationMatrix(dx,dy,dz))
        
    def rotate(self, rx, ry, rz):
        self.applyTransform(self.rotateMatrix(rx, ry, rz))
        
    def findCentre(self):
        num = len(self.points_render)
        meanX = sum([point[0] for point in self.points_render]) / num
        meanY = sum([point[1] for point in self.points_render]) / num
        meanZ = sum([point[2] for point in self.points_render]) / num
        var = True
        if var:
            return (0,0,0)
        return (meanX, meanY, meanZ)
        
    def scaleMatrix(self,sx=0, sy=0, sz=0):
        return np.array([[sx, 0,  0,  0],
                         [0,  sy, 0,  0],
                         [0,  0,  sz, 0],
                         [0,  0,  0,  1]])
    
    def translationMatrix(self,dx=0, dy=0, dz=0):
        return np.array([[1,0,0,0],
                         [0,1,0,0],
                         [0,0,1,0],
                         [dx,dy,dz,1]])
    
    def rotateXMatrix(self,radians):
        c = np.cos(radians)
        s = np.sin(radians)
        return np.array([[1, 0, 0, 0],
                         [0, c,-s, 0],
                         [0, s, c, 0],
                         [0, 0, 0, 1]])
    def rotateYMatrix(self,radians):
        c = np.cos(radians)
        s = np.sin(radians)
        return np.array([[ c, 0, s, 0],
                         [ 0, 1, 0, 0],
                         [-s, 0, c, 0],
                         [ 0, 0, 0, 1]])
    def rotateZMatrix(self,radians):
        c = np.cos(radians)
        s = np.sin(radians)
        return np.array([[c,-s, 0, 0],
                         [s, c, 0, 0],
                         [0, 0, 1, 0],
                         [0, 0, 0, 1]])
        
    def rotateMatrix(self,rx,ry,rz):
        return self.rotateXMatrix(rx).dot(self.rotateYMatrix(ry).dot(self.rotateZMatrix(rz)))

class PointViewer:
    """ Displays 3D objects on a Pygame screen """

    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.background = (10,10,10)
        self.points = Points()
        self.particles = particles.Particles()
        self.nodeColour = (255,255,255)
        self.nodeRadius = 4
        self.doTick = True
        self.tick_step = 0.01
        self.outputfile = None
        self.load()
        pygame.font.init() 
        self.myfont = pygame.font.SysFont('Arial', 30)

    def tick(self):
        if self.doTick:
            self.particles.step(self.tick_step)
            self.points.update(self.particles)
            self.outputfile.write(str(self.particles.T())+'\n')
        return

    def save(self):
        if self.particles.steps:
            self.particles.save('crystal.input')
        self.outputfile.close()

    def load(self):
        self.outputfile = open('T.output', 'w')
        size = 4.09
        dir = [0,0,1]
        axis = [0,0,1]
        atom = basisgen.Atom(107.87,47)
        #crystalgen.gen(size, dir, axis, basisgen.fccBasis(atom), 6, 0.1, -2.5*size)
        crystal = crystalgen.gen(size, dir, axis, basisgen.fccBasis(atom), 10, 0.1, -1.75*size)
        n = 10
        crystalgen.clearOutOfBounds(crystal, -size * n, size * n, -size * n, size * n)
        
        self.particles.coupling = False
        self.particles.steps = False
        self.particles.load('crystal.input')
        self.points.update(self.particles)
        self.translateAll([self.width/2,self.height/2,0])
        self.scaleAll(15)

    def onEvent(self, event):
        if event.type == pygame.KEYDOWN:
            if event.key in key_to_function:
                key_to_function[event.key](self)
            if event.key == pygame.K_KP8:
                self.particles.couplingMult *= 2
            if event.key == pygame.K_KP2:
                self.particles.couplingMult /= 2
            if event.key == pygame.K_KP6:
                self.particles.latticeMult *= 2
            if event.key == pygame.K_KP4:
                self.particles.latticeMult /= 2
        if event.type == pygame.MOUSEBUTTONDOWN:
            #scroll in
            if event.button == 4:
                self.scaleAll(1.05)
            # scroll out
            elif event.button == 5:
                self.scaleAll(1/1.05)
        if event.type == pygame.MOUSEMOTION:
            if pygame.mouse.get_pressed()[0]:
                rel = event.rel
                if rel[0] != 0:
                    self.rotateAll([0,-0.001*rel[0],0])
                if rel[1] != 0:
                    self.rotateAll([0.001 * rel[1],0,0])
            if pygame.mouse.get_pressed()[2]:
                rel = event.rel
                if rel[0] != 0:
                    self.translateAll([1*rel[0],0,0])
                if rel[1] != 0:
                    self.translateAll([0, 1*rel[1],0])
            if pygame.mouse.get_pressed()[1]:
                rel = event.rel
                if rel[0] != 0:
                    self.rotateAll([0,0,0.001 * rel[0]])

    def display(self):
        self.screen.fill(self.background)
        for point in self.points.points_other:
            pygame.draw.circle(self.screen, self.points.colour_other, (int(point[0]), int(point[1])), self.nodeRadius, 0)
        for point in self.points.points_render:
            pygame.draw.circle(self.screen, self.points.colour, (int(point[0]), int(point[1])), self.nodeRadius, 0)

        T = math.trunc(self.particles.T() * 10000)/10000
        textsurface = self.myfont.render(str(T), False, (255, 0, 0))
        self.screen.blit(textsurface,(5,0))
        pygame.display.flip()

    def translateAll(self, vector):
        self.temp = Points()
        matrix = self.temp.translationMatrix(*vector)
        self.points.applyTransform(matrix)
        return

    def scaleAll(self, scale):
        self.translateAll([-self.width/2,-self.height/2,0])
        self.temp = Points()
        matrix = self.temp.scaleMatrix(scale,scale,scale)
        shift = self.points.findCentre()
        offset = self.points.translationMatrix(-shift[0],-shift[1],-shift[2])
        self.points.applyTransform(offset)
        self.points.applyTransform(matrix)
        offset = self.points.translationMatrix(shift[0],shift[1],shift[2])
        self.points.applyTransform(offset)
        self.translateAll([self.width/2,self.height/2,0])
        return
    
    def rotateAll(self, vector):
        self.translateAll([-self.width/2, -self.height/2, 0])
        self.temp = Points()
        matrix = self.temp.rotateMatrix(*vector)
        shift = self.points.findCentre()
        offset = self.points.translationMatrix(-shift[0],-shift[1],-shift[2])
        self.points.applyTransform(offset)
        self.points.applyTransform(matrix)
        offset = self.points.translationMatrix(shift[0],shift[1],shift[2])
        self.points.applyTransform(offset)
        self.translateAll([self.width/2, self.height/2, 0])
        return

class App:
    def __init__(self):
        self._running = True
        self._display_surf = None
        self.size = self.weight, self.height = 800, 800
        self.view = PointViewer(800,800)

    def on_init(self):
        pygame.init()
        self._display_surf = pygame.display.set_mode(self.size, pygame.HWSURFACE | pygame.DOUBLEBUF)
        self.view.screen = self._display_surf
        self._running = True
 
    def on_event(self, event):
        self.view.onEvent(event)
        if event.type == pygame.QUIT:
            self._running = False

    def on_loop(self):
        self.view.tick()

    def on_render(self):
        self.view.display()

    def on_cleanup(self):
        self.view.save()
        pygame.quit()
 
    def on_execute(self):
        if self.on_init() == False:
            self._running = False
 
        while( self._running ):
            for event in pygame.event.get():
                self.on_event(event)
            self.on_loop()
            self.on_render()

        self.on_cleanup()

def makeInputBoxes(theApp):
    
    app = QApplication([])
    window = QWidget()
    layout = QGridLayout()

    #Make some buttons
    run = QPushButton('Button')
    def push():
        #Replace with whatever for running safari later.
        print(theApp.view.particles.temp())
    run.clicked.connect(push)
    
    box = QVBoxLayout()
    box.addWidget(run)

    x = 0
    y = 0
    layout.addLayout(box, x, y + 00)
    
    window.setLayout(layout)
    window.show()
    app.exec_()
 
if __name__ == "__main__" :
    theApp = App()
    theApp.on_execute()
