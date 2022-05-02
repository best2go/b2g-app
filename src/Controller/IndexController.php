<?php declare(strict_types=1);

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

class IndexController extends AbstractController
{
    /** @Route(path="/{name}", name="app_index") */
    public function indexAction(Request $request, string $name = null): Response
    {
        return $this->render('index.html.twig', [
            'name' => $name
        ]);
    }
}