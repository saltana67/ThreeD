import * as THREE from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import { ImprovedNoise } from 'three/addons/math/ImprovedNoise.js';
import { GUI } from "three/addons/libs/lil-gui.module.min.js";
import Stats from 'three/addons/libs/stats.module.js';

let perlin = new ImprovedNoise();

let scene = new THREE.Scene();
let camera = new THREE.PerspectiveCamera(60, innerWidth / innerHeight, 1, 1001);
camera.position.set(0, 5, 8).setLength(157);
let renderer = new THREE.WebGLRenderer({antialias: true});
renderer.setSize(innerWidth, innerHeight);
document.body.appendChild(renderer.domElement);

let controls = new OrbitControls(camera, renderer.domElement);

let light = new THREE.DirectionalLight(0xffffff, Math.PI * 1.25);
light.position.set(1, 1, 0);
scene.add(light, new THREE.AmbientLight(0xffffff, Math.PI * 0.25));

let g = new THREE.PlaneGeometry(200, 200, 1000, 1000);
g.rotateX(Math.PI * -0.5);
let uv = g.attributes.uv;
let pos = g.attributes.position;
let vUv = new THREE.Vector2();
for(let i = 0; i < uv.count; i++){
	vUv.fromBufferAttribute(uv, i);
  vUv.multiplyScalar(10);
  pos.setY(i, perlin.noise(vUv.x, vUv.y, 2.7) * 30);
}
g.computeVertexNormals();

const encomCyan   = new THREE.Color(0, 0.93333, 0.93333);
const encomYellow = new THREE.Color(1, 0.8, 0);
const encomLowBlue = new THREE.Color(0, 0.3, 0.93333);

let terrainUniforms = {
  min: {value: new THREE.Vector3()},
  max: {value: new THREE.Vector3()},
  showPositionColors: {value: false},
  topColor: {value: encomYellow.clone()},
  zeroColor: {value: encomCyan.clone()},
  bottomColor: {value: encomLowBlue.clone()},
//  opacity: {value: 0.2},
  offlineOpacity: {value: 0.2},
  lineOpacity: {value: 0.5},
  lineThickness: {value: 1},
  lineSpacing: {value: new THREE.Vector3(5.,5.,5.)},
  lineOffset: {value: new THREE.Vector3(0.,0.,0.)}
}
let m = new THREE.MeshLambertMaterial({
    transparent: true,
	color: 0x7D6747,
  wireframe: false,
  side: THREE.DoubleSide,
  onBeforeCompile: shader => {
  	shader.uniforms.boxMin = terrainUniforms.min;
    shader.uniforms.boxMax = terrainUniforms.max;
    shader.uniforms.bottomColor = terrainUniforms.bottomColor;
    shader.uniforms.zeroColor = terrainUniforms.zeroColor;
    shader.uniforms.topColor = terrainUniforms.topColor;
    shader.uniforms.offlineOpacity = terrainUniforms.offlineOpacity;
    shader.uniforms.lineThickness = terrainUniforms.lineThickness;
    shader.uniforms.lineSpacing = terrainUniforms.lineSpacing;
    shader.uniforms.lineOffset = terrainUniforms.lineOffset;
    shader.uniforms.showPositionColors = terrainUniforms.showPositionColors;
    shader.vertexShader = `
    	varying vec3 vPos;
      ${shader.vertexShader}
    `.replace(
    	`#include <begin_vertex>`,
      `#include <begin_vertex>
      	vPos = transformed;
      `
    );
    //console.log(shader.vertexShader);
    const yGridFragment = /*glsl*/`
      	vec3 col = vec3(0);
        col = (vPos - boxMin) / (boxMax - boxMin);
        col = clamp(col, 0., 1.);
        float opa = opacity;
      	if (showPositionColors < 0.375) {
          // http://madebyevan.com/shaders/grid/
          float coord = (vPos.y + lineOffset.y) / lineSpacing.y;
          float grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord) / lineThickness;
          float line = min(grid, 1.0);
          vec3 lineCol = mix(bottomColor,topColor, col.y);
          float o = sign(max(0.,line));
          //col = mix(vec3(0.,0.,0.),vec3(1.,1.,1.), o);
          col = mix(lineCol, gl_FragColor.rgb, line);
          col = lineCol;
          float lineOp    = (1.-line)*opacity;
          float offlineOp = line*opacity*offlineOpacity;
          opa = lineOp + offlineOp;
          //col = mix(vec3(0.,0.,0.),vec3(1.,1.,1.), line);
          //col = mix(vec3(0.,0.,0.),vec3(1.,1.,1.), 1.-line);
          //opa = 1.-(line*0.85);
          //col = mix(vec3(0.,0.,0.),vec3(1.,1.,1.), lineCol);
        }
        gl_FragColor = vec4( col, opa);
    `;
    const xzGridFragment = /*glsl*/`
      	vec3 col = vec3(0);
        //col = (vPos - boxMin) / (boxMax - boxMin);
        col = (vPos - boxMin) / (boxMax - boxMin);
        col = clamp(col, 0., 1.);
        float opa = opacity;
      	if (showPositionColors < 0.375) {
          // http://madebyevan.com/shaders/grid/
          vec2 coord = (vPos.xz + lineOffset.xz) / lineSpacing.xz;
          //coord = coord + lineOffset.xz;
          vec2 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord) / lineThickness;
          float line = min(grid.x, min(grid.y,1.0));
          vec3 upperColor = mix(zeroColor,topColor, (col.y-0.5)*2.);
          vec3 lowerColor = mix(zeroColor,bottomColor, -((col.y-0.5)*2.));
          vec3 lineCol = lowerColor * clamp(-sign((col.y-0.5)),0.,1.);
          lineCol = upperColor * clamp(sign((col.y-0.5)),0.,1.)
                     + 
                    lowerColor * clamp(-sign((col.y-0.5)),0.,1.)
                    ;
          //lineCol = mix(bottomColor,topColor, col.y);
          float o = sign(max(0.,line));
          //col = mix(vec3(0.,0.,0.),vec3(1.,1.,1.), o);
          //col = mix(lineCol, gl_FragColor.rgb, line);
          col = lineCol;
          float lineOp    = (1.-line)*opacity;
          float offlineOp = line*opacity*offlineOpacity;
          opa = lineOp + offlineOp;
          //col = mix(vec3(0.,0.,0.),vec3(1.,1.,1.), op);
          //col = mix(vec3(0.,0.,0.),vec3(1.,1.,1.), line);
          //col = mix(vec3(0.,0.,0.),vec3(1.,1.,1.), 1.-line);
          //col = mix(vec3(0.,0.,0.),vec3(1.,1.,1.), 1.-(line*0.75));
          //opa = 1.-(line*0.95);
          //opa = mix(lineOpacity,min(opacity,lineOpacity),line);
          //opa = opacity;
          //col = mix(vec3(0.,0.,0.),vec3(1.,1.,1.), lineCol);
        }
        gl_FragColor = vec4( col, opa);
    `;
    shader.fragmentShader = `
      uniform vec3 boxMin;
      uniform vec3 boxMax;
      uniform vec3 topColor;
      uniform vec3 zeroColor;
      uniform vec3 bottomColor;
      uniform float showPositionColors;
      uniform float lineThickness;
      uniform float offlineOpacity;
      uniform vec3 lineSpacing;
      uniform vec3 lineOffset;
      varying vec3 vPos;
      ${shader.fragmentShader}
    `.replace(
      `#include <dithering_fragment>`,
      xzGridFragment
    );
    console.log("shader:",shader);
  }
});
m.defines = {"USE_UV":""};
m.extensions = {derivatives: true};
let o = new THREE.Mesh(g, m);
o.layers.enable(1);
scene.add(o);

let box = new THREE.Box3().setFromObject(o);
let boxSize = new THREE.Vector3();
box.getSize(boxSize);
let boxH = new THREE.Box3Helper(box);
scene.add(boxH);
terrainUniforms.min.value.copy(box.min);
terrainUniforms.max.value.copy(box.max);

let marker = new THREE.Mesh(new THREE.SphereGeometry(5, 16, 32), new THREE.MeshLambertMaterial({color: 0xff0000}));
marker.position.setScalar(9999);
scene.add(marker);


let gui = new GUI();
gui.add(terrainUniforms.showPositionColors, "value").name("position colors");
gui.addColor(terrainUniforms.topColor, "value").name("top color");
gui.addColor(terrainUniforms.zeroColor, "value").name("zero color");
gui.addColor(terrainUniforms.bottomColor, "value").name("bottom color");
gui.add(m, "opacity", 0.1, 1).step(0.05).name("opacity")
/*     
    .onFinishChange( event => {
        
	    // event.object     // object that was modified
	    // event.property   // string, name of property
	    // event.value      // new value of controller
	    // event.controller // controller that was modified
        
        console.log("onFinishChange: event: ", event);
        console.log("onFinishChange: m.opacity: ", m.opacity);
        //m.needsUpdate = true;
    })
*/
;
let linesFolder = gui.addFolder("lines");
linesFolder.add(terrainUniforms.offlineOpacity, "value", 0, 1).step(0.05).name("offline opacity");
linesFolder.add(terrainUniforms.lineThickness, "value", 0.1, 5).step(0.1).name("line thickness");
linesFolder.add(terrainUniforms.lineSpacing.value, "x", 0.1, 50).step(0.1).name("line spacing X");
linesFolder.add(terrainUniforms.lineOffset.value, "x", -10.0, 10.0).step(0.5).name("line offset X");
linesFolder.add(terrainUniforms.lineSpacing.value, "z", 0.1, 50).step(0.1).name("line spacing Z");
linesFolder.add(terrainUniforms.lineOffset.value, "z", -10.0, 10.0).step(0.5).name("line offset Z");
linesFolder.add(terrainUniforms.lineSpacing.value, "y", 0.1, 50).step(0.1).name("line spacing Y");
linesFolder.add(terrainUniforms.lineOffset.value, "y", -10.0, 10.0).step(0.5).name("line offset Y").disable();
linesFolder.close();

let stats = new Stats();
document.body.appendChild( stats.dom );

// picking
let pointer = new THREE.Vector2();
let pickingTexture = new THREE.WebGLRenderTarget( 1, 1 );
let pixelBuffer = [];
renderer.domElement.addEventListener( 'pointermove', onPointerMove );

function pick(){
  camera.setViewOffset( renderer.domElement.width, renderer.domElement.height, pointer.x * window.devicePixelRatio | 0, pointer.y * window.devicePixelRatio | 0, 1, 1 );
  renderer.setRenderTarget( pickingTexture );
  camera.layers.set(1);
  terrainUniforms.showPositionColors.value = true;
  renderer.render( scene, camera );
  camera.clearViewOffset();
  pixelBuffer = new Uint8Array( 4 );
  
  renderer.readRenderTargetPixels( pickingTexture, 0, 0, 1, 1, pixelBuffer );
  
  //console.log(pixelBuffer);
  
  renderer.setRenderTarget( null );
  terrainUniforms.showPositionColors.value = false;
  camera.layers.set(0);
  
  marker.position.set(pixelBuffer[0], pixelBuffer[1], pixelBuffer[2])
  	.divideScalar(255)
    .multiply(boxSize)
    .add(box.min);
  //console.log(marker.position.clone());
}

function onPointerMove( e ) {

  pointer.x = e.clientX;
  pointer.y = e.clientY;
  
  pick();

}

renderer.setAnimationLoop(() => {
  renderer.render(scene, camera);
  stats.update();
})